import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lawyers_e_diary/widgets/plan_catalogue.dart';

void main() {
  testWidgets('individual catalogue shows all standard and custom tiers', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: PlanCatalogue()),
        ),
      ),
    );

    expect(find.text('Free'), findsOneWidget);
    expect(find.text('Starter'), findsOneWidget);
    expect(find.text('Professional'), findsOneWidget);
    expect(find.text('Advocate Pro'), findsOneWidget);
    expect(find.text('LEGEND'), findsOneWidget);
    expect(find.text('Custom Individual'), findsOneWidget);
    expect(find.text('What you get'), findsWidgets);
    expect(find.text('What you do not get'), findsWidgets);
  });

  testWidgets('team selector shows every chamber tier and custom plan', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: PlanCatalogue()),
        ),
      ),
    );

    await tester.tap(find.text('Chambers & firms'));
    await tester.pumpAndSettle();

    expect(find.text('Chamber Mini'), findsOneWidget);
    expect(find.text('Chamber Plus'), findsOneWidget);
    expect(find.text('Chamber Growth'), findsOneWidget);
    expect(find.text('Chamber Max'), findsOneWidget);
    expect(find.text('Chamber LEGION'), findsOneWidget);
    expect(find.text('Custom Chamber'), findsOneWidget);
    expect(find.text('Up to 50 members'), findsOneWidget);
  });

  testWidgets('reviewing a plan explains that checkout is not live', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: PlanCatalogue()),
        ),
      ),
    );

    await tester.tap(find.text('Review this plan').first);
    await tester.pumpAndSettle();

    expect(find.text('Plan details'), findsOneWidget);
    expect(
      find.textContaining('checkout, payment processing, and server-side subscription activation are not connected yet'),
      findsOneWidget,
    );
    expect(find.text('Copy request details'), findsOneWidget);
  });
}
