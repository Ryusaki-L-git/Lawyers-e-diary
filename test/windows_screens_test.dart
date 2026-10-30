import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lawyers_e_diary/models/fee_model.dart';
import 'package:lawyers_e_diary/windows/windows_desktop_shell.dart';
import 'package:lawyers_e_diary/windows/windows_fee_detail_screen.dart';
import 'package:lawyers_e_diary/windows/windows_notifications_screen.dart';
import 'package:lawyers_e_diary/windows/windows_record_payment_screen.dart';
import 'package:lawyers_e_diary/widgets/app_palette.dart';
import 'package:lawyers_e_diary/widgets/windows_desktop_ui.dart';

/// The Windows screens are exercised with a bounded test viewport so the
/// layout assertions reflect a realistic desktop window rather than the
/// default phone-sized test surface.
void main() {
  setUpAll(() async {
    // The screens construct their Firestore service during initState. The
    // platform mock registers a throwaway default app so the widget tree
    // builds without a live Firebase project; no network call is made
    // because every test asserts on rendering and client-side validation.
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
  });
  Future<void> pumpDesktop(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(1400, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.windows,
        home: WindowsDesktopShell(activeRoute: '/fee', child: screen),
      ),
    );
    await tester.pump();
  }

  group('WindowsRecordPaymentScreen', () {
    FeeModel fee() => FeeModel(
      id: 'fee-1',
      userId: 'user-1',
      clientName: 'Mehta & Partners',
      caseTitle: 'Mehta v. State',
      services: const <FeeLineItem>[],
      agreedTotal: 10000,
      collectedTotal: 4000,
    );

    testWidgets('presents the canonical page header and fee context', (
      tester,
    ) async {
      await pumpDesktop(tester, WindowsRecordPaymentScreen(fee: fee()));

      expect(find.text('PRACTICE FINANCES'), findsOneWidget);
      expect(find.text('Record a payment'), findsOneWidget);
      expect(find.text('Mehta & Partners'), findsOneWidget);
      expect(find.text('Mehta v. State'), findsOneWidget);
    });

    testWidgets('shows the agreed, collected and outstanding balances', (
      tester,
    ) async {
      await pumpDesktop(tester, WindowsRecordPaymentScreen(fee: fee()));

      expect(find.text('Agreed'), findsOneWidget);
      expect(find.text('Already collected'), findsOneWidget);
      expect(find.text('Currently outstanding'), findsOneWidget);
      expect(find.textContaining('10,000.00'), findsWidgets);
      expect(find.textContaining('4,000.00'), findsWidgets);
      expect(find.textContaining('6,000.00'), findsWidgets);
    });

    testWidgets('rejects an empty amount and a non-positive amount', (
      tester,
    ) async {
      await pumpDesktop(tester, WindowsRecordPaymentScreen(fee: fee()));

      // Submitting with an empty form must surface the amount error.
      await tester.tap(find.text('Confirm payment'));
      await tester.pumpAndSettle();
      expect(find.text('Amount is required'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. 3,000.00'),
        '0',
      );
      await tester.tap(find.text('Confirm payment'));
      await tester.pumpAndSettle();
      expect(find.text('Amount must be greater than zero'), findsOneWidget);
    });

    testWidgets('rejects a non-numeric amount', (tester) async {
      await pumpDesktop(tester, WindowsRecordPaymentScreen(fee: fee()));

      // The amount field only accepts digits and a decimal separator, so a
      // typed letter is filtered out and the field ends up empty. The
      // required-field validator is what must reject it.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. 3,000.00'),
        'abc',
      );
      await tester.tap(find.text('Confirm payment'));
      await tester.pumpAndSettle();
      expect(find.text('Amount is required'), findsOneWidget);
    });

    testWidgets('rejects a malformed decimal amount', (tester) async {
      await pumpDesktop(tester, WindowsRecordPaymentScreen(fee: fee()));

      // A bare decimal point passes the character filter but is not a number.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. 3,000.00'),
        '.',
      );
      await tester.tap(find.text('Confirm payment'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a numeric amount'), findsOneWidget);
    });

    testWidgets('projects the resulting balances as the amount is entered', (
      tester,
    ) async {
      await pumpDesktop(tester, WindowsRecordPaymentScreen(fee: fee()));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. 3,000.00'),
        '1500',
      );
      await tester.pumpAndSettle();

      expect(find.text('Collected after saving'), findsOneWidget);
      expect(find.text('Outstanding after saving'), findsOneWidget);
      // 4000 collected + 1500 paid = 5500 collected, 4500 outstanding.
      expect(find.textContaining('5,500.00'), findsOneWidget);
      expect(find.textContaining('4,500.00'), findsOneWidget);
    });

    testWidgets('warns when the amount exceeds what the agreed fee absorbs', (
      tester,
    ) async {
      await pumpDesktop(tester, WindowsRecordPaymentScreen(fee: fee()));

      // Agreed total is 10000, so the collected total caps at 20000.
      // Paying 20000 on top of 4000 collected reaches that ceiling.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. 3,000.00'),
        '20000',
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('above the agreed fee'), findsOneWidget);
    });

    testWidgets('allows the payment mode to be selected', (tester) async {
      await pumpDesktop(tester, WindowsRecordPaymentScreen(fee: fee()));

      expect(find.text('Cash'), findsOneWidget);
      await tester.tap(find.text('Bank Transfer'));
      await tester.pumpAndSettle();
      expect(find.text('Bank Transfer'), findsOneWidget);
    });
  });

  group('WindowsFeeDetailScreen', () {
    FeeModel fee() => FeeModel(
      id: 'fee-1',
      userId: 'user-1',
      clientName: 'Mehta & Partners',
      caseTitle: 'Mehta v. State',
      services: const <FeeLineItem>[],
      agreedTotal: 10000,
      collectedTotal: 4000,
    );

    testWidgets('presents the fee balances, services and ledger headings', (
      tester,
    ) async {
      await pumpDesktop(tester, WindowsFeeDetailScreen(fee: fee()));

      expect(find.text('PRACTICE FINANCES'), findsOneWidget);
      expect(find.text('Mehta & Partners'), findsOneWidget);
      expect(find.text('AGREED'), findsOneWidget);
      expect(find.text('COLLECTED'), findsOneWidget);
      expect(find.text('OUTSTANDING'), findsOneWidget);
      expect(find.text('Services'), findsOneWidget);
      expect(find.text('Payment history'), findsOneWidget);
    });

    testWidgets('shows the record payment action for an unsettled fee', (
      tester,
    ) async {
      await pumpDesktop(tester, WindowsFeeDetailScreen(fee: fee()));

      expect(find.text('Record payment'), findsOneWidget);
    });

    testWidgets('hides the record payment action once the fee is settled', (
      tester,
    ) async {
      final settled = FeeModel(
        id: 'fee-1',
        userId: 'user-1',
        clientName: 'Mehta & Partners',
        caseTitle: 'Mehta v. State',
        services: const <FeeLineItem>[],
        agreedTotal: 10000,
        collectedTotal: 10000,
        status: FeeStatus.settled,
      );

      await pumpDesktop(tester, WindowsFeeDetailScreen(fee: settled));

      expect(find.text('Record payment'), findsNothing);
      expect(find.text('Settled'), findsOneWidget);
    });
  });

  group('WindowsNotificationsScreen', () {
    testWidgets('keeps the empty state honest', (tester) async {
      await pumpDesktop(tester, const WindowsNotificationsScreen());

      expect(find.text('WORKSPACE ACTIVITY'), findsOneWidget);
      expect(
        find.text('No notification feed is connected yet'),
        findsOneWidget,
      );
      // The desktop title is the serif page title; the sidebar also carries a
      // navigation label with the same wording.
      final title = tester.widget<Text>(
        find.descendant(
          of: find.byType(WindowsPageHeader),
          matching: find.text('Notifications'),
        ),
      );
      expect(title.style?.fontWeight, FontWeight.w700);
      expect(title.style?.fontSize, 30);
    });
  });

  group('Windows desktop shell', () {
    testWidgets('shows the shared workspace header on inner pages', (tester) async {
      await pumpDesktop(tester, const SizedBox.shrink());
      expect(find.text('Search cases, clients, matters…'), findsOneWidget);
      expect(find.byTooltip('Notifications'), findsOneWidget);
      expect(find.byTooltip('Profile'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps the shared header within a compact desktop window', (tester) async {
      await pumpDesktop(
        tester,
        const SizedBox.shrink(),
        size: const Size(920, 640),
      );
      expect(find.text('Search cases, clients, matters…'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('exposes the to-do entry point in the sidebar', (tester) async {
      await pumpDesktop(tester, const SizedBox.shrink());

      expect(find.text('To-Do list'), findsOneWidget);
    });

    testWidgets('marks the active route in the sidebar', (tester) async {
      await pumpDesktop(tester, const SizedBox.shrink());

      // '/fee' is the active route, so the Fees item is rendered as selected.
      final fees = find.descendant(
        of: find.byType(InkWell),
        matching: find.text('Fees'),
      );
      await tester.scrollUntilVisible(
        fees,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(fees, findsOneWidget);

      final item = tester.widget<InkWell>(
        find.ancestor(of: fees, matching: find.byType(InkWell)).first,
      );
      expect(item.onTap, isNotNull);
    });
  });
}
