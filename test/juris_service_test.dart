import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lawyers_e_diary/screens/juris/juris_chat_screen.dart';

void main() {
  testWidgets('JURIS screen presents its legal-intelligence chat interface',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: JurisChatScreen()),
    );

    expect(find.text('JURIS'), findsOneWidget);
    expect(find.text('Legal intelligence'), findsOneWidget);
    expect(find.text('Ask JURIS…'), findsOneWidget);
    expect(find.textContaining('Use verified sources for legal research'),
        findsOneWidget);
  });
}
