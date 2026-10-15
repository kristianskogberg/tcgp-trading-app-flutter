import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tcgp_trading_app/widgets/settings_screen/preferred_language_tile.dart';
import 'package:tcgp_trading_app/widgets/shared/language_picker_sheet.dart';

/// Holds the saved language the way the Settings screen does: it changes
/// only once [save] succeeds.
class _Settings extends StatefulWidget {
  final String? preferredLanguage;
  final bool loading;
  final Future<void> Function(String) save;

  const _Settings(this.preferredLanguage, this.loading, this.save);

  @override
  State<_Settings> createState() => _SettingsState();
}

class _SettingsState extends State<_Settings> {
  late String? _language = widget.preferredLanguage;

  @override
  Widget build(BuildContext context) => PreferredLanguageTile(
        preferredLanguage: _language,
        loading: widget.loading,
        save: (language) async {
          await widget.save(language);
          setState(() => _language = language);
        },
      );
}

Future<void> _pumpTile(
  WidgetTester tester, {
  String? preferredLanguage,
  bool loading = false,
  required Future<void> Function(String) save,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: _Settings(preferredLanguage, loading, save)),
  ));
}

/// Opens the picker from the tile and chooses [languageName].
Future<void> _choose(WidgetTester tester, String languageName) async {
  await tester.tap(find.byType(PreferredLanguageTile));
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(
    of: find.byType(LanguagePickerSheet),
    matching: find.text(languageName),
  ));
  await tester.pump();
  await tester.tap(find.text('Done'));
  // Not pumpAndSettle: the saving spinner animates until the save finishes.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('shows that an unset preference falls back to English',
      (tester) async {
    await _pumpTile(tester, save: (_) async {});
    expect(find.text('Preferred language'), findsOneWidget);
    expect(find.text('English (default)'), findsOneWidget);
  });

  testWidgets('shows the chosen language', (tester) async {
    await _pumpTile(tester, preferredLanguage: 'JPN', save: (_) async {});
    expect(find.text('Japanese'), findsOneWidget);
  });

  testWidgets("can't be changed until the saved language is known",
      (tester) async {
    await _pumpTile(tester, loading: true, save: (_) async {});
    expect(find.text('English (default)'), findsNothing);

    await tester.tap(find.byType(PreferredLanguageTile));
    await tester.pumpAndSettle();
    expect(find.byType(LanguagePickerSheet), findsNothing);
  });

  testWidgets('the picker offers one specific language, not "any language"',
      (tester) async {
    await _pumpTile(tester, save: (_) async {});
    await tester.tap(find.byType(PreferredLanguageTile));
    await tester.pumpAndSettle();

    final sheet =
        tester.widget<LanguagePickerSheet>(find.byType(LanguagePickerSheet));
    expect(sheet.showAny, isFalse);
    expect(sheet.multiSelect, isFalse);
    expect(sheet.selected, {'ENG'});
  });

  testWidgets('choosing a language saves it and shows it', (tester) async {
    final saved = <String>[];
    await _pumpTile(tester, save: (l) async => saved.add(l));

    await _choose(tester, 'Japanese');

    expect(saved, ['JPN']);
    expect(find.text('Japanese'), findsOneWidget);
  });

  testWidgets('shows progress while saving', (tester) async {
    final pending = Completer<void>();
    await _pumpTile(tester, save: (_) => pending.future);

    await _choose(tester, 'French');
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('French'), findsOneWidget);
  });

  testWidgets('a failed save keeps the old language and says so',
      (tester) async {
    await _pumpTile(tester,
        preferredLanguage: 'DEU', save: (_) async => throw Exception('offline'));

    await _choose(tester, 'Korean');

    expect(find.text('German'), findsOneWidget);
    expect(find.text("Couldn't save your preferred language. Try again."),
        findsOneWidget);
  });
}
