import 'package:cloud_firestore/cloud_firestore.dart';

import '../repositories/case_repository.dart';
import 'auth_identity.dart';

Object? _normalizeFirestoreValue(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is Map) {
    return value.map(
      (key, item) => MapEntry(key.toString(), _normalizeFirestoreValue(item)),
    );
  }
  if (value is List) return value.map(_normalizeFirestoreValue).toList();
  return value;
}

class RemoteCaseDocument {
  const RemoteCaseDocument({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;

  DateTime? get updatedAt {
    final value = data['updatedAt'] ?? data['lastUpdated'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  int get cloudVersion => (data['cloudVersion'] as num?)?.toInt() ?? 0;
}

abstract interface class CaseSyncDataSource {
  Future<bool> isCloudSubscriber();
  Future<RemoteCaseDocument?> readOwnedCase(String caseId);
  Future<List<RemoteCaseDocument>> fetchOwnedCases();
  Future<void> writeOwnedCase(
    String caseId,
    Map<String, dynamic> data, {
    required int? expectedCloudVersion,
    required DateTime? expectedUpdatedAt,
  });
}

class FirestoreCaseSyncDataSource implements CaseSyncDataSource {
  FirestoreCaseSyncDataSource({
    FirebaseFirestore? firestore,
    AppIdentity? identity,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _identity = identity ?? FirebaseAuthIdentity.instance;

  final FirebaseFirestore _firestore;
  final AppIdentity _identity;

  String get _uid {
    final uid = _identity.currentUserId;
    if (uid == null || uid.isEmpty) {
      throw StateError('Cannot sync Cases without an authenticated user.');
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _cases =>
      _firestore.collection('cases');

  @override
  Future<bool> isCloudSubscriber() async {
    final snapshot = await _firestore.collection('users').doc(_uid).get();
    final data = snapshot.data() ?? const <String, dynamic>{};
    final subscription = data['subscription'];
    return subscription is Map && subscription['tier'] == 'cloud_subscriber';
  }

  @override
  Future<RemoteCaseDocument?> readOwnedCase(String caseId) async {
    final uid = _uid;
    final canonical = await _cases
        .where(FieldPath.documentId, isEqualTo: caseId)
        .where('ownerUid', isEqualTo: uid)
        .limit(1)
        .get();
    final result = canonical.docs.isNotEmpty
        ? canonical
        : await _cases
              .where(FieldPath.documentId, isEqualTo: caseId)
              .where('userId', isEqualTo: uid)
              .where('ownerUid', isNull: true)
              .limit(1)
              .get();
    if (result.docs.isEmpty) return null;
    final document = result.docs.single;
    final rawData = document.data();
    if ((rawData['ownerUid'] ?? rawData['userId']) != uid) {
      throw StateError(
        'Firestore returned a Case outside the authenticated owner scope.',
      );
    }
    final data = Map<String, dynamic>.from(rawData)..['ownerUid'] = uid;
    return RemoteCaseDocument(
      id: document.id,
      data: Map<String, dynamic>.from(_normalizeFirestoreValue(data) as Map),
    );
  }

  @override
  Future<List<RemoteCaseDocument>> fetchOwnedCases() async {
    final uid = _uid;
    final results = await Future.wait([
      _cases.where('ownerUid', isEqualTo: uid).get(),
      _cases
          .where('userId', isEqualTo: uid)
          .where('ownerUid', isNull: true)
          .get(),
    ]);
    final documents = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final result in results) {
      for (final document in result.docs) {
        final data = document.data();
        if ((data['ownerUid'] ?? data['userId']) == uid) {
          documents[document.id] = document;
        }
      }
    }

    return documents.values.map((document) {
      final normalized = Map<String, dynamic>.from(
        _normalizeFirestoreValue(document.data()) as Map,
      )..['ownerUid'] = uid;
      return RemoteCaseDocument(id: document.id, data: normalized);
    }).toList();
  }

  @override
  Future<void> writeOwnedCase(
    String caseId,
    Map<String, dynamic> data, {
    required int? expectedCloudVersion,
    required DateTime? expectedUpdatedAt,
  }) async {
    final uid = _uid;
    if (data['ownerUid'] != uid) {
      throw StateError(
        'Refusing to write a Case outside the authenticated owner scope.',
      );
    }

    // Entitlement is read from the server-owned user document. Missing or
    // unknown subscription state fails closed to CNR-only cloud registration.
    final userSnapshot = await _firestore.collection('users').doc(uid).get();
    final userData = userSnapshot.data() ?? const <String, dynamic>{};
    final subscription = userData['subscription'];
    final isCloudSubscriber =
        subscription is Map && subscription['tier'] == 'cloud_subscriber';
    final ownerLedId = userData['ledId'];

    final rawCnr = data['cuid'] ?? data['cnrNumber'] ?? data['cnr'];
    final cnr = rawCnr is String ? rawCnr.trim().toUpperCase() : '';
    if (!RegExp(r'^[A-Z0-9]{16}$').hasMatch(cnr)) {
      throw StateError('A valid 16-character CNR is required for cloud registration.');
    }
    for (final alias in const ['cuid', 'cnrNumber', 'cnr']) {
      final value = data[alias];
      if (value is String && value.trim().isNotEmpty &&
          value.trim().toUpperCase() != cnr) {
        throw StateError(
          'The stored CUID and CNR fields do not match. Resolve this case before syncing.',
        );
      }
    }

    Map<String, dynamic> payload;
    if (isCloudSubscriber) {
      payload = Map<String, dynamic>.from(data)
        ..['cuid'] = cnr
        ..['cnrNumber'] = cnr
        ..['caseNumber'] = cnr
        ..['cloudStorageMode'] = 'full';
    } else {
      final createdAt = data['createdAt'] ?? DateTime.now();
      final updatedAt = data['updatedAt'] ?? data['lastUpdated'] ?? DateTime.now();
      payload = <String, dynamic>{
        'ownerUid': uid,
        'userId': uid,
        'cuid': cnr,
        'cnrNumber': cnr,
        'caseNumber': cnr,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'lastUpdated': updatedAt,
        'cloudVersion': (data['cloudVersion'] as num?)?.toInt() ?? 1,
        'cloudStorageMode': 'cnr_only',
      };
    }

    if (ownerLedId is String && ownerLedId.trim().isNotEmpty) {
      payload['ownerLedId'] = ownerLedId.trim();
    }

    final reference = _cases.doc(caseId);
    final registryReference = _firestore
        .collection('users')
        .doc(uid)
        .collection('case_cuid_registry')
        .doc(cnr);
    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(reference);
      final registry = await transaction.get(registryReference);
      DocumentReference<Map<String, dynamic>>? replaceStubReference;
      var replacingCnrOnlyStub = false;

      if (existing.exists) {
        final existingData = existing.data()!;
        if ((existingData['ownerUid'] ?? existingData['userId']) != uid) {
          throw StateError(
            'Firestore Case ID is already owned by another user.',
          );
        }
      }

      final registeredCaseId = registry.data()?['caseId'];
      if (registry.exists && registeredCaseId != caseId) {
        if (registeredCaseId is! String || registeredCaseId.isEmpty) {
          throw StateError(
            'The CNR registry requires migration before this case can sync.',
          );
        }
        if (existing.exists) {
          throw StateError(
            'Two cloud case records already exist for this CNR. Resolve the duplicate without merging private data.',
          );
        }

        final registeredReference = _cases.doc(registeredCaseId);
        replaceStubReference = registeredReference;
        final registeredSnapshot = await transaction.get(registeredReference);
        if (!registeredSnapshot.exists) {
          throw StateError(
            'The CNR registry points to a missing case record; migration is required.',
          );
        }
        final registeredData = registeredSnapshot.data()!;
        final registeredRawCnr = registeredData['cuid'] ??
            registeredData['cnrNumber'] ??
            registeredData['cnr'];
        final registeredCnr = registeredRawCnr is String
            ? registeredRawCnr.trim().toUpperCase()
            : '';
        if ((registeredData['ownerUid'] ?? registeredData['userId']) != uid ||
            registeredCnr != cnr ||
            registeredData['cloudStorageMode'] != 'cnr_only') {
          throw StateError(
            'This CNR already has a non-stub cloud record in your account. Resolve the duplicate without overwriting private data.',
          );
        }
        // A transfer may have created a CNR-only cloud stub before this
        // device's private local case synced. Re-key that empty stub to the
        // local case ID, preserving the local private workspace.
        replacingCnrOnlyStub = true;
      }

      if (!registry.exists && !existing.exists && expectedCloudVersion != null) {
        throw StateError('Firestore Case changed during synchronization.');
      }
      if (registry.exists && !existing.exists && !replacingCnrOnlyStub) {
        throw StateError(
          'The CNR registry points to a missing case record; migration is required.',
        );
      }

      if (existing.exists) {
        final current = existing.data()!;
        final currentVersion = (current['cloudVersion'] as num?)?.toInt() ?? 0;
        final currentUpdatedValue = current['updatedAt'] ?? current['lastUpdated'];
        final currentUpdatedAt = currentUpdatedValue is Timestamp
            ? currentUpdatedValue.toDate()
            : currentUpdatedValue is DateTime
            ? currentUpdatedValue
            : currentUpdatedValue is String
            ? DateTime.tryParse(currentUpdatedValue)
            : null;
        if (currentVersion != expectedCloudVersion ||
            currentUpdatedAt != expectedUpdatedAt) {
          throw StateError('Firestore Case changed during synchronization.');
        }
      }

      // Create or move the per-user CNR registry in the same transaction as
      // the case write. A move is permitted only when replacing an empty CNR
      // stub, never a full case record.
      if (!registry.exists) {
        transaction.set(registryReference, <String, dynamic>{
          'uid': uid,
          'cuid': cnr,
          'caseId': caseId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else if (replacingCnrOnlyStub) {
        transaction.set(
          registryReference,
          <String, dynamic>{
            'uid': uid,
            'cuid': cnr,
            'caseId': caseId,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        transaction.delete(replaceStubReference!);
      }

      // Replace Free-tier documents to remove previously stored private fields.
      // Subscriber writes merge to preserve server/team-owned fields.
      transaction.set(
        reference,
        payload,
        SetOptions(merge: isCloudSubscriber),
      );
    });
  }

  }

class CaseSyncResult {
  const CaseSyncResult({
    this.uploaded = 0,
    this.downloaded = 0,
    this.conflicts = 0,
    this.failed = 0,
    this.rejected = 0,
    this.pullError,
  });

  final int uploaded;
  final int downloaded;
  final int conflicts;
  final int failed;
  final int rejected;
  final String? pullError;
}

class CaseSyncEngine {
  factory CaseSyncEngine({
    required CaseRepository repository,
    required CaseSyncDataSource dataSource,
  }) => CaseSyncEngine._(repository, dataSource);

  CaseSyncEngine._(this._repository, this._dataSource);

  final CaseRepository _repository;
  final CaseSyncDataSource _dataSource;

  Future<CaseSyncResult> sync() async {
    _repository.currentUserId;
    var uploaded = 0;
    var downloaded = 0;
    var conflicts = 0;
    var failed = 0;
    var rejected = 0;
    final conflictsHandled = <String>{};
    String? pullError;

    final isCloudSubscriber = await _dataSource.isCloudSubscriber();
    if (isCloudSubscriber) {
      // Promote existing CNR-only registrations using this advocate's local
      // workspace after the server confirms Cloud Subscriber entitlement.
      final localRecords = await _repository.getCasesForCurrentUser();
      for (final record in localRecords) {
        final remote = await _dataSource.readOwnedCase(record.id);
        if (remote?.data['cloudStorageMode'] == 'cnr_only') {
          await _repository.saveCase(record);
        }
      }
    } else {
      // Scrub private fields from legacy/full cloud documents after a downgrade
      // or first Free-tier sync. Local records are untouched. Invalid legacy
      // CNRs are skipped and reported for a deliberate migration rather than
      // risking deletion of a record that cannot be identified safely.
      final remoteCases = await _dataSource.fetchOwnedCases();
      for (final remote in remoteCases) {
        if (remote.data['cloudStorageMode'] == 'cnr_only') continue;
        try {
          await _dataSource.writeOwnedCase(
            remote.id,
            remote.data,
            expectedCloudVersion: remote.cloudVersion,
            expectedUpdatedAt: remote.updatedAt,
          );
        } catch (_) {
          failed++;
        }
      }
    }

    final pending = await _repository.getPendingCaseChanges();
    for (final change in pending) {
      try {
        final remote = await _dataSource.readOwnedCase(change.record.id);
        if (remote != null &&
            remote.data['ownerUid'] != change.record.ownerUid) {
          rejected++;
          continue;
        }

        if (remote != null &&
            remote.data['cloudStorageMode'] != 'cnr_only' &&
            remote.updatedAt != null &&
            remote.updatedAt!.isAfter(change.record.updatedAt)) {
          await _repository.markCaseConflict(
            caseId: change.record.id,
            expectedRevision: change.revision,
            remoteData: remote.data,
            cloudVersion: remote.cloudVersion,
          );
          conflictsHandled.add(change.record.id);
          conflicts++;
          continue;
        }

        final version = remote == null
            ? 1
            : remote.updatedAt != null &&
                  change.record.updatedAt.isAfter(remote.updatedAt!)
            ? remote.cloudVersion + 1
            : (remote.cloudVersion == 0 ? 1 : remote.cloudVersion);
        await _dataSource.writeOwnedCase(
          change.record.id,
          change.record.toCloudMap(cloudVersion: version),
          expectedCloudVersion: remote?.cloudVersion,
          expectedUpdatedAt: remote?.updatedAt,
        );
        await _repository.markCaseSynchronized(
          caseId: change.record.id,
          expectedRevision: change.revision,
          expectedUpdatedAt: change.record.updatedAt,
          cloudVersion: version,
        );
        uploaded++;
      } catch (error) {
        await _repository.markCaseSyncFailed(
          caseId: change.record.id,
          expectedRevision: change.revision,
          error: error,
        );
        failed++;
      }
    }

    try {
      final remoteCases = await _dataSource.fetchOwnedCases();
      final localRecords = await _repository.getCasesForCurrentUser();
      final localIds = localRecords.map((record) => record.id).toSet();
      for (final remote in remoteCases) {
        if (conflictsHandled.contains(remote.id)) {
          continue;
        }
        final uid = _repository.currentUserId;
        if (remote.data['ownerUid'] != uid) {
          rejected++;
          continue;
        }
        // Never let a cloud-only CNR stub overwrite a full local workspace.
        if (remote.data['cloudStorageMode'] == 'cnr_only' &&
            localIds.contains(remote.id)) {
          continue;
        }
        final syncedAt = DateTime.now();
        final record = LocalCaseRecord.fromCloudMap(
          id: remote.id,
          ownerUid: uid,
          data: remote.data,
          lastSyncedAt: syncedAt,
          cloudVersion: remote.cloudVersion,
        );
        final outcome = await _repository.applyRemoteCase(
          remoteCase: record,
          remoteData: remote.data,
        );
        if (outcome == 'applied') downloaded++;
        if (outcome == 'conflict') conflicts++;
      }
    } catch (error) {
      pullError = error.toString();
    }

    return CaseSyncResult(
      uploaded: uploaded,
      downloaded: downloaded,
      conflicts: conflicts,
      failed: failed,
      rejected: rejected,
      pullError: pullError,
    );
  }
}
