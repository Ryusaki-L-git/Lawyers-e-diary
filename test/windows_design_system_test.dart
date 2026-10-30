import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lawyers_e_diary/models/fee_model.dart';
import 'package:lawyers_e_diary/models/todo_model.dart';
import 'package:lawyers_e_diary/widgets/app_palette.dart';
import 'package:lawyers_e_diary/widgets/platform_app_bar.dart';
import 'package:lawyers_e_diary/widgets/windows_desktop_ui.dart';

void main() {
  group('Canonical Modern Legal Editorial palette', () {
    test('exposes the exact design tokens required by the standard', () {
      expect(AppPalette.canvas, const Color(0xFFF7F5F2));
      expect(AppPalette.primaryGreen, const Color(0xFF1F3D2B));
      expect(AppPalette.accentGold, const Color(0xFFCCA046));
      expect(AppPalette.cardBackground, const Color(0xFFFFFFFF));
      expect(AppPalette.textPrimary, const Color(0xFF1A1A1A));
      expect(AppPalette.textMuted, const Color(0xFF6B665E));
      expect(AppPalette.borderLight, const Color(0xFFE5DFD7));
    });
  });

  group('To-Do model', () {
    test('round-trips through the Firestore map representation', () {
      final created = DateTime(2026, 3, 4, 10, 30);
      final model = TodoModel(
        id: 'todo-1',
        userId: 'user-1',
        title: 'Draft the plaint',
        description: 'Check the cause of action',
        caseId: 'case-9',
        caseTitle: 'Mehta v. State',
        priority: TodoPriority.high,
        dueDateTime: created,
      );

      final map = model.toMap();
      expect(map['userId'], 'user-1');
      expect(map['title'], 'Draft the plaint');
      expect(map['priority'], 'high');
      expect(map['isCompleted'], isFalse);

      final restored = TodoModel.fromMap('todo-1', map);
      expect(restored.id, 'todo-1');
      expect(restored.userId, 'user-1');
      expect(restored.title, 'Draft the plaint');
      expect(restored.description, 'Check the cause of action');
      expect(restored.caseId, 'case-9');
      expect(restored.caseTitle, 'Mehta v. State');
      expect(restored.priority, TodoPriority.high);
      expect(restored.dueDateTime, created);
      expect(restored.isCompleted, isFalse);
    });

    test('treats an unknown priority as normal rather than failing', () {
      final model = TodoModel.fromMap('t', <String, dynamic>{
        'userId': 'u',
        'title': 'Task',
        'priority': 'not-a-priority',
      });
      expect(model.priority, TodoPriority.normal);
    });

    test('flags an overdue task only while it is still open', () {
      final past = DateTime.now().subtract(const Duration(days: 2));
      final future = DateTime.now().add(const Duration(days: 2));

      final overdue = TodoModel(
        id: 't',
        userId: 'u',
        title: 'Late task',
        dueDateTime: past,
      );
      final overdueDone = overdue.copyWith(isCompleted: true);
      final upcoming = TodoModel(
        id: 't',
        userId: 'u',
        title: 'Later task',
        dueDateTime: future,
      );

      expect(overdue.isOverdue, isTrue);
      expect(overdue.isDueSoon, isFalse);
      expect(overdueDone.isOverdue, isFalse);
      expect(upcoming.isOverdue, isFalse);
      expect(upcoming.isDueSoon, isTrue);
    });

    test('copyWith records a completion timestamp only when completing', () {
      final open = TodoModel(id: 't', userId: 'u', title: 'Task');
      expect(open.completedAt, isNull);

      final completed = open.copyWith(isCompleted: true);
      expect(completed.isCompleted, isTrue);
      expect(completed.completedAt, isNotNull);

      final reopened = completed.copyWith(isCompleted: false);
      expect(reopened.isCompleted, isFalse);
      expect(reopened.completedAt, isNull);
    });
  });

  group('Fee model payment semantics', () {
    FeeModel buildFee({double agreed = 1000, double collected = 0}) {
      return FeeModel(
        id: 'fee-1',
        userId: 'user-1',
        clientName: 'Mehta & Partners',
        caseTitle: 'Mehta v. State',
        services: const <FeeLineItem>[],
        agreedTotal: agreed,
        collectedTotal: collected,
      );
    }

    test('derives the outstanding balance from agreed minus collected', () {
      expect(buildFee(agreed: 1000).pendingTotal, 1000);
      expect(buildFee(agreed: 1000, collected: 400).pendingTotal, 600);
    });

    test('never reports a negative outstanding balance', () {
      final fee = buildFee(agreed: 1000, collected: 1500);
      expect(fee.pendingTotal, 0);
    });

    test('parses a partially paid status from storage', () {
      final model = FeeModel.fromMap('fee-1', <String, dynamic>{
        'userId': 'u',
        'clientName': 'C',
        'caseTitle': 'T',
        'agreedTotal': 100,
        'collectedTotal': 40,
        'status': 'partially_paid',
      });
      expect(model.status, FeeStatus.partiallyPaid);
      expect(model.status.label, 'Partially Paid');
    });
  });

  group('Windows action sizing', () {
    test('primary and secondary actions use compact desktop dimensions', () {
      final primary = WindowsButtonStyles.primary();
      final secondary = WindowsButtonStyles.secondary();

      expect(primary.minimumSize?.resolve({})?.height, 40);
      expect(secondary.minimumSize?.resolve({})?.height, 40);
      expect(primary.tapTargetSize, MaterialTapTargetSize.shrinkWrap);
      expect(secondary.tapTargetSize, MaterialTapTargetSize.shrinkWrap);
      expect(primary.visualDensity, VisualDensity.compact);
      expect(secondary.visualDensity, VisualDensity.compact);
    });
  });

  group('Shared Windows desktop components', () {
    testWidgets('WindowsPageHeader renders eyebrow, serif title and subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WindowsPageHeader(
              eyebrow: 'PRACTICE FINANCES',
              title: 'Fee ledger',
              subtitle: 'Agreed and collected balances.',
            ),
          ),
        ),
      );

      expect(find.text('PRACTICE FINANCES'), findsOneWidget);
      expect(find.text('Fee ledger'), findsOneWidget);
      expect(find.text('Agreed and collected balances.'), findsOneWidget);

      final eyebrow = tester.widget<Text>(find.text('PRACTICE FINANCES'));
      expect(eyebrow.style?.color, AppPalette.textMuted);
      expect(eyebrow.style?.letterSpacing, 1.5);

      final title = tester.widget<Text>(find.text('Fee ledger'));
      expect(title.style?.color, AppPalette.primaryGreen);
      expect(title.style?.fontWeight, FontWeight.w700);
    });

    testWidgets('WindowsMessageState renders the failure state', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WindowsMessageState(
              icon: Icons.error_outline_rounded,
              title: 'Could not load',
              message: 'The feed is unavailable.',
              isError: true,
            ),
          ),
        ),
      );

      expect(find.text('Could not load'), findsOneWidget);
      expect(find.text('The feed is unavailable.'), findsOneWidget);
    });

    testWidgets('WindowsPanel renders its title and content', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WindowsPanel(
              title: 'Balances',
              child: Text('Inside the panel'),
            ),
          ),
        ),
      );

      expect(find.text('Balances'), findsOneWidget);
      expect(find.text('Inside the panel'), findsOneWidget);

      final panel = tester.widget<Container>(find.byType(Container).first);
      final decoration = panel.decoration as BoxDecoration?;
      expect(decoration?.color, AppPalette.cardBackground);
    });
  });

  group('PlatformAppBar', () {
    testWidgets('renders the title on every platform', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(appBar: PlatformAppBar(title: 'Record payment')),
        ),
      );

      expect(find.text('Record payment'), findsOneWidget);
    });
  });
}
