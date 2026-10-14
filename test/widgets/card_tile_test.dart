import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tcgp_trading_app/collection/collection.dart';
import 'package:tcgp_trading_app/collection/collection_draft.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/models/home_mode.dart';
import 'package:tcgp_trading_app/widgets/shared/card_tile.dart';
import 'package:tcgp_trading_app/widgets/shared/language_picker_sheet.dart';

final _card = PocketCard(
  id: 'A1-001',
  name: 'Bulbasaur',
  rarity: '◊',
  pack: 'Mewtwo',
  imageUrl: '',
  type: 'grass',
  cardType: 'pokemon',
);

/// An edit-mode tile wired to a draft the way the edit flows wire it.
class _DraftTile extends StatefulWidget {
  final CollectionDraft draft;

  const _DraftTile(this.draft);

  @override
  State<_DraftTile> createState() => _DraftTileState();
}

class _DraftTileState extends State<_DraftTile> {
  late CollectionDraft _draft = widget.draft;

  @override
  Widget build(BuildContext context) {
    final state = _draft.stateOf(_card.id);
    return SizedBox(
      width: 140,
      height: 200,
      child: CardTile(
        card: _card,
        mode: HomeMode.edit,
        isPendingWishlist: state is Wishlisted,
        isPendingListing: state is Listed,
        languageChoices: _draft.languageChoicesFor(_card.id),
        pendingLanguages: switch (state) {
          Wishlisted(:final languages) => languages,
          Listed(:final language) => {language},
          NotInCollection() => {_draft.preferredLanguage},
        },
        onWishlistToggle: () =>
            setState(() => _draft = _draft.toggleWishlist(_card.id)),
        onListingToggle: () =>
            setState(() => _draft = _draft.toggleListing(_card.id)),
        onLanguagesChanged: (id, languages) =>
            setState(() => _draft = _draft.setLanguages(id, languages)),
      ),
    );
  }
}

/// The "any language" choice in the open language picker.
final _anyChoice = find.descendant(
  of: find.byType(LanguagePickerSheet),
  matching: find.text('Any'),
);

Future<void> _pumpTile(WidgetTester tester, Collection collection) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: Center(child: _DraftTile(CollectionDraft(collection)))),
  ));
}

/// Lets sheets finish animating. pumpAndSettle never returns here because
/// the card image placeholder animates forever.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('a multi-language wishlist entry collapses to one language '
      'when listed', (tester) async {
    await _pumpTile(
      tester,
      Collection(wishlist: [
        WishlistEntry(cardId: _card.id, languages: {'FRA', 'JPN'}),
      ]),
    );
    expect(find.textContaining('FRA'), findsOneWidget);

    await tester.tap(find.text('Have'));
    await tester.pump();

    // JPN comes before FRA in the app's language order.
    expect(find.text('JPN'), findsOneWidget);
    expect(find.textContaining('FRA'), findsNothing);
  });

  testWidgets('a listing offers one specific language', (tester) async {
    await _pumpTile(
      tester,
      Collection(listings: [Listing(cardId: _card.id, language: 'FRA')]),
    );

    await tester.tap(find.text('FRA'));
    await _settle(tester);

    expect(_anyChoice, findsNothing);
    await tester.tap(find.text('Korean'));
    await tester.tap(find.text('Japanese'));
    await tester.tap(find.text('Done'));
    await _settle(tester);
    expect(find.text('JPN'), findsOneWidget);
  });

  testWidgets('a wishlist entry offers several languages or "any"',
      (tester) async {
    await _pumpTile(
      tester,
      Collection(wishlist: [
        WishlistEntry(cardId: _card.id, languages: {'ENG'}),
      ]),
    );

    await tester.tap(find.text('ENG'));
    await _settle(tester);

    expect(_anyChoice, findsOneWidget);
    await tester.tap(find.text('Korean'));
    await tester.tap(find.text('Done'));
    await _settle(tester);
    expect(find.text('ENG, KOR'), findsOneWidget);
  });
}
