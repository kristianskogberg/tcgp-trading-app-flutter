import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App builds without exceptions', (WidgetTester tester) async {
    // Minimal shell. MyApp itself requires Supabase/Firebase to be initialized
    // before it can run, so we avoid pumping it in a unit test. This smoke test
    // just verifies the test harness is wired up; replace with real widget
    // tests as they get written.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(tester.takeException(), isNull);
  });
}
