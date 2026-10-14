import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tcgp_trading_app/collection/collection.dart';
import 'package:tcgp_trading_app/collection/collection_draft.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/widgets/card_screen/edit_card_dialog.dart';

final _card = PocketCard(
  id: 'A1-001',
  name: 'Bulbasaur',
  rarity: '◊',
  pack: 'Mewtwo',
  imageUrl: '',
  type: 'grass',
  cardType: 'pokemon',
);

final _condition = TradeCondition(cardId: 'A1-002', languages: {'ANY'});

const _error =
    "Couldn't save your changes. Check your connection and try again.";

/// Opens the dialog for a card listed in FRA with one trade condition and
/// returns what the dialog popped with once it closes.
Future<ValueNotifier<bool?>> _openDialog(
  WidgetTester tester,
  Future<void> Function(Map<String, CardState>) save,
) async {
  final result = ValueNotifier<bool?>(null);
  final draft = CollectionDraft(Collection(listings: [
    Listing(cardId: _card.id, language: 'FRA', tradeConditions: [_condition]),
  ]));

  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          result.value = await showDialog<bool>(
            context: context,
            builder: (_) => EditCardDialog(
              card: _card,
              draft: draft,
              kind: CollectionItemKind.listing,
              isEditing: true,
              save: save,
            ),
          );
        },
        child: const Text('open'),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await _settle(tester);
  return result;
}

/// Lets dialogs, sheets and saves finish. pumpAndSettle never returns here
/// because the card image placeholder animates forever.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('changing the listing language keeps its trade conditions',
      (tester) async {
    final saves = <Map<String, CardState>>[];
    final result = await _openDialog(tester, (changes) async {
      saves.add(changes);
    });

    await tester.tap(find.text('FRA'));
    await _settle(tester);
    await tester.tap(find.text('Korean'));
    await tester.tap(find.text('Done'));
    await _settle(tester);
    await tester.tap(find.text('Save'));
    await _settle(tester);

    expect(saves.single, {
      _card.id: Listed('KOR', tradeConditions: [_condition]),
    });
    expect(result.value, isTrue);
    expect(find.byType(EditCardDialog), findsNothing);
  });

  testWidgets('a failed save keeps the dialog open with one error',
      (tester) async {
    final saves = <Map<String, CardState>>[];
    var failing = true;
    final result = await _openDialog(tester, (changes) async {
      saves.add(changes);
      if (failing) throw Exception('offline');
    });

    await tester.tap(find.text('Have'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await _settle(tester);

    expect(find.byType(EditCardDialog), findsOneWidget);
    expect(find.text(_error), findsOneWidget);

    // Retrying keeps the user's choices and still shows a single error.
    await tester.tap(find.text('Save'));
    await _settle(tester);
    expect(find.text(_error), findsOneWidget);
    expect(saves, hasLength(2));
    expect(saves[1], saves[0]);
    expect(saves[1], {_card.id: const NotInCollection()});

    failing = false;
    await tester.tap(find.text('Save'));
    await _settle(tester);
    expect(find.byType(EditCardDialog), findsNothing);
    expect(result.value, isTrue);
  });

  testWidgets('saving without changes closes without calling save',
      (tester) async {
    var saved = false;
    final result = await _openDialog(tester, (_) async => saved = true);

    await tester.tap(find.text('Save'));
    await _settle(tester);

    expect(saved, isFalse);
    expect(result.value, isFalse);
  });
}
