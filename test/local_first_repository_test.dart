import 'package:flutter_test/flutter_test.dart';
import 'package:lawyers_e_diary/data/local/app_database.dart';
import 'package:lawyers_e_diary/models/case_model.dart';
import 'package:lawyers_e_diary/repositories/case_repository.dart';
import 'package:lawyers_e_diary/repositories/client_repository.dart';
import 'package:lawyers_e_diary/services/auth_identity.dart';

void main() {
  late AppDatabase database;

  setUp(() async {
    database = AppDatabase.memory();
  });

  tearDown(() async {
    await database.close();
  });

  LocalCaseRecord buildCaseRecord({
    required String id,
    required String ownerUid,
    String title = 'Sample case',
    String status = 'active',
  }) {
    return LocalCaseRecord(
      id: id,
      ownerUid: ownerUid,
      caseNumber: 'CNR-$id',
      caseTitle: title,
      clientName: 'Client $ownerUid',
      opponentName: 'Opponent',
      courtName: 'District Court',
      status: status,
      caseType: 'Civil',
      handledBy: 'Advocate A',
      clientPhone: '9999999999',
      isStarred: false,
      assignedUserUid: ownerUid,
      teamId: null,
      caseSource: 'manual',
      lifecycleMode: 'manual',
      documents: const [
        CaseDocumentModel(name: 'summary.pdf', type: 'PDF', size: '1.2 MB'),
      ],
      notes: const ['Initial note'],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      deletedAt: null,
      isDeleted: false,
    );
  }

  LocalClientRecord buildClientRecord({
    required String id,
    required String ownerUid,
    String name = 'Alpha Client',
  }) {
    return LocalClientRecord(
      id: id,
      ownerUid: ownerUid,
      name: name,
      type: 'Individual',
      phone: '9999999999',
      email: 'alpha@example.com',
      address: 'Delhi',
      notes: 'test',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isDeleted: false,
      deletedAt: null,
    );
  }

  group('local-first case repository', () {
    test(
      'user A can create, read, update and soft-delete their own case',
      () async {
        final repo = CaseRepository(
          database: database,
          identity: const TestAuthIdentity('user-a'),
        );

        final record = buildCaseRecord(id: 'case-1', ownerUid: 'user-a');
        final id = await repo.saveCase(record);

        expect(id, 'case-1');

        final persisted = await repo.getCaseById('case-1');
        expect(persisted, isNotNull);
        expect(persisted!.caseTitle, 'Sample case');
        expect(persisted.documents, hasLength(1));
        expect(persisted.notes, contains('Initial note'));

        await repo.saveCase(
          record.copyWith(
            caseTitle: 'Updated title',
            status: 'completed',
            updatedAt: DateTime.now(),
          ),
        );
        final updated = await repo.getCaseById('case-1');
        expect(updated, isNotNull);
        expect(updated!.caseTitle, 'Updated title');
        expect(updated.status, 'completed');

        await repo.softDeleteCase('case-1');
        final deleted = await repo.getCaseById('case-1');
        expect(deleted, isNotNull);
        expect(deleted!.isDeleted, isTrue);
      },
    );

    test(
      'a persisted case round-trips through the legacy CaseModel shape',
      () async {
        final repo = CaseRepository(
          database: database,
          identity: const TestAuthIdentity('user-a'),
        );

        final record = buildCaseRecord(
          id: 'case-roundtrip',
          ownerUid: 'user-a',
          title: 'Round trip case',
        );
        await repo.saveCase(record);

        final cases = await repo.watchCasesForCurrentUser().first;
        expect(cases, hasLength(1));
        expect(cases.first.caseTitle, 'Round trip case');
        expect(cases.first.caseNumber, 'CNR-case-roundtrip');
        expect(cases.first.documents, hasLength(1));
        expect(cases.first.notes, contains('Initial note'));
        expect(cases.first.userId, 'user-a');
      },
    );

    test(
      'create preserves its generated ID, authenticated owner, and timestamps',
      () async {
        final repo = CaseRepository(
          database: database,
          identity: const TestAuthIdentity('user-a'),
        );

        final id = await repo.createCase(
          caseTitle: 'Created locally',
          caseNumber: 'ABCD1234EFGH5678',
          clientName: 'Client user-a',
          opponentName: 'Opponent',
          courtName: 'District Court',
          caseType: 'Civil',
          status: 'ACTIVE',
          handledBy: 'Advocate A',
          notes: const ['Created note'],
        );
        final persisted = await repo.getCaseById(id);

        expect(id, startsWith('case_'));
        expect(persisted, isNotNull);
        expect(persisted!.id, id);
        expect(persisted.ownerUid, 'user-a');
        expect(persisted.status, 'active');
        expect(persisted.createdAt, persisted.updatedAt);
        expect(persisted.notes, contains('Created note'));
      },
    );

    test(
      'same CNR is idempotent within one advocate but independent across advocates',
      () async {
        final repoA = CaseRepository(
          database: database,
          identity: const TestAuthIdentity('user-a'),
        );
        final firstId = await repoA.createCase(
          caseTitle: 'Private A case',
          caseNumber: 'ABCD1234EFGH5678',
          clientName: 'Client A',
          opponentName: 'Opponent A',
          courtName: 'District Court',
          caseType: 'Civil',
          status: 'active',
          handledBy: 'Advocate A',
          notes: const ['Private note A'],
        );
        final duplicateId = await repoA.createCase(
          caseTitle: 'Second attempt',
          caseNumber: 'abcd1234efgh5678',
          clientName: 'Different client',
          opponentName: 'Opponent',
          courtName: 'Other Court',
          caseType: 'Civil',
          status: 'active',
          handledBy: 'Advocate A',
        );
        expect(duplicateId, firstId);
        expect((await repoA.getCaseById(firstId))!.notes, ['Private note A']);

        final repoB = CaseRepository(
          database: database,
          identity: const TestAuthIdentity('user-b'),
        );
        final secondId = await repoB.createCase(
          caseTitle: 'Private B case',
          caseNumber: 'ABCD1234EFGH5678',
          clientName: 'Client B',
          opponentName: 'Opponent B',
          courtName: 'District Court',
          caseType: 'Civil',
          status: 'active',
          handledBy: 'Advocate B',
          notes: const ['Private note B'],
        );
        expect(secondId, isNot(firstId));
        expect((await repoB.getCaseById(secondId))!.ownerUid, 'user-b');
        expect((await repoB.getCaseById(secondId))!.notes, ['Private note B']);
        expect((await repoA.getCaseById(firstId))!.clientName, 'Client A');
      },
    );

    test('createCase rejects malformed CNR values', () async {
      final repo = CaseRepository(
        database: database,
        identity: const TestAuthIdentity('user-a'),
      );
      await expectLater(
        repo.createCase(
          caseTitle: 'Invalid CNR',
          caseNumber: 'CNR-123',
          clientName: 'Client',
          opponentName: 'Opponent',
          courtName: 'District Court',
          caseType: 'Civil',
          status: 'active',
          handledBy: 'Advocate A',
        ),
        throwsArgumentError,
      );
    });

    test(
      'star, unstar, soft-delete, and restore stay in the local repository',
      () async {
        final repo = CaseRepository(
          database: database,
          identity: const TestAuthIdentity('user-a'),
        );
        await repo.saveCase(
          buildCaseRecord(id: 'case-actions', ownerUid: 'user-a'),
        );

        await repo.setCaseStarred('case-actions', true);
        expect((await repo.getCaseById('case-actions'))!.isStarred, isTrue);
        await repo.setCaseStarred('case-actions', false);
        expect((await repo.getCaseById('case-actions'))!.isStarred, isFalse);

        await repo.softDeleteCase('case-actions');
        expect(await repo.watchCasesForCurrentUser().first, isEmpty);
        expect((await repo.getCaseById('case-actions'))!.isDeleted, isTrue);

        await repo.restoreCase('case-actions');
        expect((await repo.watchCasesForCurrentUser().first), hasLength(1));
        expect((await repo.getCaseById('case-actions'))!.isDeleted, isFalse);
      },
    );

    test(
      'list query applies ownership, search, filters, dates, and sorting',
      () async {
        final userARepo = CaseRepository(
          database: database,
          identity: const TestAuthIdentity('user-a'),
        );
        final userBRepo = CaseRepository(
          database: database,
          identity: const TestAuthIdentity('user-b'),
        );
        final hearingDate = DateTime(2026, 10, 10);

        await userARepo.saveCase(
          buildCaseRecord(
            id: 'case-z',
            ownerUid: 'user-a',
            title: 'Zeta motion',
          ).copyWith(nextHearingDate: hearingDate),
        );
        await userARepo.saveCase(
          buildCaseRecord(
            id: 'case-a',
            ownerUid: 'user-a',
            title: 'Alpha motion',
          ).copyWith(nextHearingDate: hearingDate.add(const Duration(days: 1))),
        );
        await userBRepo.saveCase(
          buildCaseRecord(
            id: 'case-other-user',
            ownerUid: 'user-b',
            title: 'Zeta motion',
          ),
        );

        final cases = await userARepo
            .watchCasesForCurrentUser(
              caseType: 'civ',
              handledBy: 'advocate a',
              searchQuery: 'motion',
              hearingDateFrom: hearingDate,
              hearingDateTo: hearingDate.add(const Duration(days: 2)),
              sortBy: 'title',
            )
            .first;

        expect(cases.map((item) => item.id), ['case-a', 'case-z']);
      },
    );

    test('user B cannot read, update or delete user A\'s case', () async {
      final userARepo = CaseRepository(
        database: database,
        identity: const TestAuthIdentity('user-a'),
      );
      final userBRepo = CaseRepository(
        database: database,
        identity: const TestAuthIdentity('user-b'),
      );

      final record = buildCaseRecord(id: 'case-2', ownerUid: 'user-a');
      await userARepo.saveCase(record);

      expect(await userBRepo.getCaseById('case-2'), isNull);
      expect(await userBRepo.getCasesForCurrentUser(), isEmpty);

      await expectLater(
        () => userBRepo.saveCase(record.copyWith(caseTitle: 'Hacked title')),
        throwsA(isA<StateError>()),
      );

      await expectLater(
        () => userBRepo.softDeleteCase('case-2'),
        throwsA(isA<StateError>()),
      );
      final fresh = await userARepo.getCaseById('case-2');
      expect(fresh, isNotNull);
      expect(fresh!.isDeleted, isFalse);
    });

    test('attempting to save a case owned by another user throws', () async {
      final repo = CaseRepository(
        database: database,
        identity: const TestAuthIdentity('user-b'),
      );
      final record = buildCaseRecord(id: 'case-3', ownerUid: 'user-a');

      await expectLater(
        () => repo.saveCase(record),
        throwsA(isA<StateError>()),
      );
    });

    test('cannot replace another user case by reusing its ID', () async {
      final userARepo = CaseRepository(
        database: database,
        identity: const TestAuthIdentity('user-a'),
      );
      final userBRepo = CaseRepository(
        database: database,
        identity: const TestAuthIdentity('user-b'),
      );
      await userARepo.saveCase(
        buildCaseRecord(id: 'shared-case-id', ownerUid: 'user-a'),
      );

      await expectLater(
        () => userBRepo.saveCase(
          buildCaseRecord(id: 'shared-case-id', ownerUid: 'user-b'),
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        (await userARepo.getCaseById('shared-case-id'))!.ownerUid,
        'user-a',
      );
    });
  });

  group('hearing purpose persistence', () {
    test(
      'a hearing purpose survives the local round trip into the case model',
      () async {
        final repo = CaseRepository(
          database: database,
          identity: const TestAuthIdentity('user-a'),
        );

        await repo.saveCase(
          buildCaseRecord(id: 'case-purpose', ownerUid: 'user-a').copyWith(
            hearingPurpose: 'Interim application',
            nextHearingDate: DateTime(2026, 10, 25),
          ),
        );

        final persisted = await repo.getCaseById('case-purpose');
        expect(persisted, isNotNull);
        expect(persisted!.hearingPurpose, 'Interim application');

        // The case model is what every screen and the WhatsApp helper read.
        final model = persisted.toCaseModel();
        expect(model.hearingPurpose, 'Interim application');
        expect(model.nextHearingDate, DateTime(2026, 10, 25));
      },
    );

    test('a case without a hearing purpose keeps it absent', () async {
      final repo = CaseRepository(
        database: database,
        identity: const TestAuthIdentity('user-a'),
      );

      await repo.saveCase(
        buildCaseRecord(id: 'case-no-purpose', ownerUid: 'user-a'),
      );

      final persisted = await repo.getCaseById('case-no-purpose');
      expect(persisted, isNotNull);
      expect(persisted!.hearingPurpose, isNull);
      expect(persisted.toCaseModel().hearingPurpose, isNull);
    });

    test('the hearing purpose is carried into the cloud payload', () async {
      final record = buildCaseRecord(
        id: 'case-cloud',
        ownerUid: 'user-a',
      ).copyWith(hearingPurpose: 'Admission');
      final cloud = record.toCloudMap(cloudVersion: 1);

      expect(cloud['hearingPurpose'], 'Admission');
      expect(cloud['ownerUid'], 'user-a');
      expect(cloud['userId'], 'user-a');
    });

    test(
      'a cloud payload without a hearing purpose omits the field entirely',
      () async {
        final record = buildCaseRecord(
          id: 'case-cloud-none',
          ownerUid: 'user-a',
        );
        final cloud = record.toCloudMap(cloudVersion: 1);

        expect(cloud.containsKey('hearingPurpose'), isFalse);
      },
    );

    test(
      'a case downloaded from the cloud keeps the recorded hearing purpose',
      () async {
        final record = LocalCaseRecord.fromCloudMap(
          id: 'case-remote',
          ownerUid: 'user-a',
          data: {
            'ownerUid': 'user-a',
            'userId': 'user-a',
            'caseTitle': 'Remote case',
            'cnrNumber': 'CNR-REMOTE',
            'clientName': 'Client',
            'courtName': 'Court',
            'caseType': 'Civil',
            'status': 'active',
            'hearingPurpose': 'Evidence',
            'caseSource': 'smart_backend',
          },
          lastSyncedAt: DateTime.now(),
          cloudVersion: 1,
        );

        expect(record.hearingPurpose, 'Evidence');
        expect(record.caseSource, 'smart_backend');
        expect(record.toCaseModel().hearingPurpose, 'Evidence');
      },
    );
  });

  group('local-first client repository', () {
    test(
      'user A can create, read, update and soft-delete their own client',
      () async {
        final repo = ClientRepository(
          database: database,
          identity: const TestAuthIdentity('user-a'),
        );

        final record = buildClientRecord(id: 'client-1', ownerUid: 'user-a');
        await repo.saveClient(record);

        final persisted = await repo.getClientById('client-1');
        expect(persisted, isNotNull);
        expect(persisted!.name, 'Alpha Client');

        await repo.saveClient(
          record.copyWith(name: 'Updated Client', updatedAt: DateTime.now()),
        );
        final updated = await repo.getClientById('client-1');
        expect(updated, isNotNull);
        expect(updated!.name, 'Updated Client');

        await repo.softDeleteClient('client-1');
        final deleted = await repo.getClientById('client-1');
        expect(deleted, isNotNull);
        expect(deleted!.isDeleted, isTrue);
      },
    );

    test('user B cannot read, update or delete user A\'s client', () async {
      final userARepo = ClientRepository(
        database: database,
        identity: const TestAuthIdentity('user-a'),
      );
      final userBRepo = ClientRepository(
        database: database,
        identity: const TestAuthIdentity('user-b'),
      );

      final record = buildClientRecord(id: 'client-2', ownerUid: 'user-a');
      await userARepo.saveClient(record);

      expect(await userBRepo.getClientById('client-2'), isNull);
      expect(await userBRepo.getClientsForCurrentUser(), isEmpty);

      await expectLater(
        () => userBRepo.saveClient(record.copyWith(name: 'Hacked client')),
        throwsA(isA<StateError>()),
      );

      await userBRepo.softDeleteClient('client-2');
      final fresh = await userARepo.getClientById('client-2');
      expect(fresh, isNotNull);
      expect(fresh!.isDeleted, isFalse);
    });

    test('attempting to save a client owned by another user throws', () async {
      final repo = ClientRepository(
        database: database,
        identity: const TestAuthIdentity('user-b'),
      );
      final record = buildClientRecord(id: 'client-3', ownerUid: 'user-a');

      await expectLater(
        () => repo.saveClient(record),
        throwsA(isA<StateError>()),
      );
    });
  });
}
