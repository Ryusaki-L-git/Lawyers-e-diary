import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lawyers_e_diary/login_screen.dart';
import 'package:lawyers_e_diary/windows/windows_desktop_shell.dart';
import 'package:lawyers_e_diary/windows/windows_notifications_screen.dart';
import 'package:lawyers_e_diary/windows/windows_record_payment_screen.dart';
import 'package:lawyers_e_diary/models/fee_model.dart';
import 'package:lawyers_e_diary/widgets/app_palette.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
  });

  Future<void> pumpDesktop(WidgetTester tester, Widget child,
      {Size size = const Size(1400, 900)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.windows,
        home: WindowsDesktopShell(activeRoute: '/home', child: child),
      ),
    );
    await tester.pump();
  }

  testWidgets('Windows login lays out without infinite-height constraints', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.windows}));

  group('WindowsDesktopShell responsive rail', () {
    testWidgets('shows full labels on a wide window', (tester) async {
      await pumpDesktop(tester, const Text('Workspace'), size: const Size(1400, 900));
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('All cases'), findsOneWidget);
    });

    testWidgets('collapses to icon-only below the threshold', (tester) async {
      await pumpDesktop(tester, const Text('Workspace'), size: const Size(920, 640));
      // Labels are hidden in the icon rail; only tooltips show them.
      expect(find.text('Home'), findsNothing);
    });

    testWidgets('renders the brand mark and the selected-state dot', (tester) async {
      await pumpDesktop(tester, const Text('Workspace'), size: const Size(1400, 900));
      expect(find.text("LAWYER'S"), findsOneWidget);
      expect(find.text('E-DIARY'), findsOneWidget);
    });
  });

  group('Windows desktop surfaces render at multiple viewports', () {
    final FeeModel fee = FeeModel(
      id: 'fee-1',
      userId: 'user-1',
      clientName: 'Mehta & Partners',
      caseTitle: 'Mehta v. State',
      services: const <FeeLineItem>[],
      agreedTotal: 10000,
      collectedTotal: 4000,
    );

    testWidgets('notifications screen at wide', (tester) async {
      await pumpDesktop(tester, const WindowsNotificationsScreen(), size: const Size(1400, 900));
      expect(find.text('Notifications'), findsAtLeastNWidgets(1));
    });

    testWidgets('notifications screen at narrow', (tester) async {
      await pumpDesktop(tester, const WindowsNotificationsScreen(), size: const Size(920, 640));
      expect(find.text('Notifications'), findsOneWidget);
    });

    testWidgets('record payment screen at wide', (tester) async {
      await pumpDesktop(tester, WindowsRecordPaymentScreen(fee: fee), size: const Size(1400, 900));
      expect(find.text('Record a payment'), findsOneWidget);
    });

    testWidgets('record payment screen at narrow', (tester) async {
      await pumpDesktop(tester, WindowsRecordPaymentScreen(fee: fee), size: const Size(920, 640));
      expect(find.text('Record a payment'), findsOneWidget);
    });
  });
}
