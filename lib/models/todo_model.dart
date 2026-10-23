import 'package:cloud_firestore/cloud_firestore.dart';

/// Domain model for a personal to-do item stored in the Firestore `todos`
/// collection.
///
/// The storage conventions deliberately mirror [ReminderModel]: every document
/// carries the owning `userId`, the Firestore rules scope access to that
/// owner, and completion is expressed with an `isCompleted` flag. A to-do has
/// no required due date, so `dueDateTime` is optional and a task without a
/// deadline is simply not scheduled.
class TodoModel {
  const TodoModel({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.caseId,
    this.caseTitle,
    this.priority = TodoPriority.normal,
    this.dueDateTime,
    this.isCompleted = false,
    this.completedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String title;
  final String? description;
  final String? caseId;
  final String? caseTitle;
  final TodoPriority priority;
  final DateTime? dueDateTime;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// True when the task carries a deadline that has already passed and the
  /// task is still open.
  bool get isOverdue =>
      !isCompleted &&
      dueDateTime != null &&
      dueDateTime!.isBefore(DateTime.now());

  /// True when the task carries a deadline that is still ahead.
  bool get isDueSoon =>
      !isCompleted &&
      dueDateTime != null &&
      dueDateTime!.isAfter(DateTime.now());

  factory TodoModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};
    return TodoModel.fromMap(snapshot.id, data);
  }

  factory TodoModel.fromMap(String id, Map<String, dynamic> data) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return TodoModel(
      id: id,
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? 'Task',
      description: data['description'] as String?,
      caseId: data['caseId'] as String?,
      caseTitle: data['caseTitle'] as String?,
      priority: TodoPriorityExt.fromString(data['priority'] as String?),
      dueDateTime: parseDate(data['dueDateTime']),
      isCompleted: data['isCompleted'] as bool? ?? false,
      completedAt: parseDate(data['completedAt']),
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      if (description != null) 'description': description,
      if (caseId != null) 'caseId': caseId,
      if (caseTitle != null) 'caseTitle': caseTitle,
      'priority': priority.value,
      if (dueDateTime != null) 'dueDateTime': Timestamp.fromDate(dueDateTime!),
      'isCompleted': isCompleted,
      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  TodoModel copyWith({
    String? title,
    String? description,
    String? caseId,
    String? caseTitle,
    TodoPriority? priority,
    DateTime? dueDateTime,
    bool? isCompleted,
  }) {
    return TodoModel(
      id: id,
      userId: userId,
      title: title ?? this.title,
      description: description ?? this.description,
      caseId: caseId ?? this.caseId,
      caseTitle: caseTitle ?? this.caseTitle,
      priority: priority ?? this.priority,
      dueDateTime: dueDateTime ?? this.dueDateTime,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: isCompleted == true
          ? DateTime.now()
          : (isCompleted == false ? null : completedAt),
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

/// Priority levels a to-do item can carry.
enum TodoPriority { low, normal, high }

extension TodoPriorityExt on TodoPriority {
  String get value {
    switch (this) {
      case TodoPriority.low:
        return 'low';
      case TodoPriority.normal:
        return 'normal';
      case TodoPriority.high:
        return 'high';
    }
  }

  String get label {
    switch (this) {
      case TodoPriority.low:
        return 'Low';
      case TodoPriority.normal:
        return 'Normal';
      case TodoPriority.high:
        return 'High';
    }
  }

  static TodoPriority fromString(String? value) {
    switch (value) {
      case 'low':
        return TodoPriority.low;
      case 'high':
        return TodoPriority.high;
      default:
        return TodoPriority.normal;
    }
  }
}
