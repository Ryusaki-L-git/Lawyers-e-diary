import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an attached file/document on a case.
class CaseDocumentModel {
  const CaseDocumentModel({
    required this.name,
    required this.type,
    this.size = '1.2 MB',
    this.url,
  });

  final String name;
  final String type;
  final String size;
  final String? url;

  factory CaseDocumentModel.fromMap(Map<String, dynamic> map) {
    return CaseDocumentModel(
      name: map['name'] as String? ?? 'Document.pdf',
      type: map['type'] as String? ?? 'PDF',
      size: map['size'] as String? ?? '1.2 MB',
      url: map['url'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'size': size,
      if (url != null) 'url': url,
    };
  }
}

/// Core model representing a legal case docket in Lawyer's E-Diary.
class CaseModel {
  const CaseModel({
    required this.id,
    required this.caseTitle,
    required this.caseNumber,
    required this.clientName,
    this.opponentName = '',
    this.courtName = 'Court Room 3',
    this.caseType = 'Civil Case',
    this.status = 'active',
    this.nextHearingDate,
    this.hearingPurpose,
    this.caseSource = 'manual',
    this.handledBy = 'Advocate',
    this.userId = '',
    this.clientPhone,
    this.isStarred = false,
    this.documents = const [],
    this.notes = const [],
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.teamId,
    this.teamOwnerUid,
    this.assignedTo,
    this.assignedToName,
  });

  final String id;
  final String caseTitle;
  final String caseNumber;
  final String clientName;
  final String opponentName;
  final String courtName;
  final String caseType;
  final String status; // active, upcoming, urgent, completed, deleted
  final DateTime? nextHearingDate;
  final String? hearingPurpose;
  final String caseSource;
  final String handledBy;
  final String userId;
  final String? clientPhone;
  final bool isStarred;
  final List<CaseDocumentModel> documents;
  final List<String> notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  /// Team assignment metadata. These fields are read from Firestore for
  /// team-aware views but are intentionally not written by the legacy
  /// CaseModel.toMap() path. TeamService owns assignment mutations.
  final String? teamId;
  final String? teamOwnerUid;
  final String? assignedTo;
  final String? assignedToName;

  /// Canonical court-case identity. It is intentionally derived from the
  /// normalized CNR, not from the per-advocate LED case record ID.
  String get cuid => caseNumber.trim().toUpperCase();

  bool get isDeleted => status.toLowerCase() == 'deleted';
  bool get isCompleted => status.toLowerCase() == 'completed';
  bool get isActive => status.toLowerCase() == 'active';
  bool get isUpcoming => status.toLowerCase() == 'upcoming';
  bool get isUrgent => status.toLowerCase() == 'urgent';
  String get title => caseTitle;

  factory CaseModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};
    return CaseModel.fromMap(snapshot.id, data);
  }

  factory CaseModel.fromMap(String id, Map<String, dynamic> data) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final rawDocs = data['documents'];
    final docList = <CaseDocumentModel>[];
    if (rawDocs is List) {
      for (final item in rawDocs) {
        if (item is Map<String, dynamic>) {
          docList.add(CaseDocumentModel.fromMap(item));
        } else if (item is String) {
          docList.add(CaseDocumentModel(name: item, type: 'Document'));
        }
      }
    }

    final rawNotes = data['notes'];
    final noteList = <String>[];
    if (rawNotes is List) {
      for (final n in rawNotes) {
        if (n != null) noteList.add(n.toString());
      }
    }

    return CaseModel(
      id: id,
      caseTitle:
          data['caseTitle'] as String? ??
          data['title'] as String? ??
          'Untitled Case',
      caseNumber:
          data['cnrNumber'] as String? ??
          data['caseNumber'] as String? ??
          'ID: C-2024-001',
      clientName: data['clientName'] as String? ?? 'Client',
      opponentName: data['opponentName'] as String? ?? '',
      courtName: data['courtName'] as String? ?? 'High Court',
      caseType: data['caseType'] as String? ?? 'Civil Case',
      status: (data['status'] as String? ?? 'active').toLowerCase(),
      nextHearingDate: parseDate(data['nextHearingDate']),
      hearingPurpose:
          (data['hearingPurpose'] as String?) ??
          (data['nextHearingPurpose'] as String?) ??
          (data['purpose'] as String?) ??
          (data['hearingReason'] as String?),
      caseSource: data['caseSource'] as String? ?? 'manual',
      handledBy: data['handledBy'] as String? ?? 'Adv. Counsel',
      userId: data['userId'] as String? ?? '',
      clientPhone:
          data['clientPhone'] as String? ??
          data['phone'] as String? ??
          data['whatsappNumber'] as String?,
      isStarred: data['isStarred'] as bool? ?? false,
      documents: docList,
      notes: noteList,
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt'] ?? data['lastUpdated']),
      deletedAt: parseDate(data['deletedAt']),
      teamId: data['teamId'] as String?,
      teamOwnerUid: data['teamOwnerUid'] as String?,
      assignedTo: data['assignedTo'] as String?,
      assignedToName: data['assignedToName'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'caseTitle': caseTitle,
      'cnrNumber': caseNumber,
      'clientName': clientName,
      'opponentName': opponentName,
      'courtName': courtName,
      'caseType': caseType,
      'status': status,
      if (nextHearingDate != null)
        'nextHearingDate': Timestamp.fromDate(nextHearingDate!),
      if (hearingPurpose != null && hearingPurpose!.trim().isNotEmpty)
        'hearingPurpose': hearingPurpose,
      'caseSource': caseSource,
      'handledBy': handledBy,
      'userId': userId,
      if (clientPhone != null) 'clientPhone': clientPhone,
      'isStarred': isStarred,
      'documents': documents.map((d) => d.toMap()).toList(),
      'notes': notes,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (deletedAt != null) 'deletedAt': Timestamp.fromDate(deletedAt!),
    };
  }

  CaseModel copyWith({
    String? caseTitle,
    String? caseNumber,
    String? clientName,
    String? opponentName,
    String? courtName,
    String? caseType,
    String? status,
    DateTime? nextHearingDate,
    String? hearingPurpose,
    String? caseSource,
    String? handledBy,
    String? userId,
    String? clientPhone,
    bool? isStarred,
    List<CaseDocumentModel>? documents,
    List<String>? notes,
    DateTime? deletedAt,
    String? teamId,
    String? teamOwnerUid,
    String? assignedTo,
    String? assignedToName,
  }) {
    return CaseModel(
      id: id,
      caseTitle: caseTitle ?? this.caseTitle,
      caseNumber: caseNumber ?? this.caseNumber,
      clientName: clientName ?? this.clientName,
      opponentName: opponentName ?? this.opponentName,
      courtName: courtName ?? this.courtName,
      caseType: caseType ?? this.caseType,
      status: status ?? this.status,
      nextHearingDate: nextHearingDate ?? this.nextHearingDate,
      hearingPurpose: hearingPurpose ?? this.hearingPurpose,
      caseSource: caseSource ?? this.caseSource,
      handledBy: handledBy ?? this.handledBy,
      userId: userId ?? this.userId,
      clientPhone: clientPhone ?? this.clientPhone,
      isStarred: isStarred ?? this.isStarred,
      documents: documents ?? this.documents,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      deletedAt: deletedAt ?? this.deletedAt,
      teamId: teamId ?? this.teamId,
      teamOwnerUid: teamOwnerUid ?? this.teamOwnerUid,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
    );
  }
}
