import 'package:flutter_test/flutter_test.dart';
import 'package:tcgp_trading_app/collection/collection.dart';
import 'package:tcgp_trading_app/collection/collection_draft.dart';

final _condition = TradeCondition(cardId: 'A1-002', languages: {'ANY'});

final _saved = Collection(
  wishlist: [
    WishlistEntry(cardId: 'wish-any', languages: {'ANY'}),
    WishlistEntry(cardId: 'wish-jpn-fra', languages: {'FRA', 'JPN'}),
  ],
  listings: [
    Listing(cardId: 'listed', language: 'FRA', tradeConditions: [_condition]),
  ],
);

CollectionDraft _draft({String? preferredLanguage}) =>
    CollectionDraft(_saved, preferredLanguage: preferredLanguage);

void _expectWishlisted(CardState state, Set<String> languages) {
  expect(state, isA<Wishlisted>());
  expect((state as Wishlisted).languages, languages);
}

void _expectListed(
  CardState state,
  String language, {
  List<TradeCondition> tradeConditions = const [],
}) {
  expect(state, isA<Listed>());
  final listed = state as Listed;
  expect(listed.language, language);
  expect(sameTradeConditions(listed.tradeConditions, tradeConditions), isTrue,
      reason: 'trade conditions differ');
}

void main() {
  group('a new draft', () {
    test('shows the saved state of each card', () {
      final draft = _draft();
      _expectWishlisted(draft.stateOf('wish-any'), {'ANY'});
      _expectListed(draft.stateOf('listed'), 'FRA',
          tradeConditions: [_condition]);
      expect(draft.stateOf('unknown'), isA<NotInCollection>());
    });

    test('has no changes', () {
      final draft = _draft();
      expect(draft.hasChanges, isFalse);
      expect(draft.changes, isEmpty);
    });

    test('prefers ENG when no preferred language is given', () {
      expect(_draft().preferredLanguage, 'ENG');
      expect(_draft(preferredLanguage: 'KOR').preferredLanguage, 'KOR');
    });
  });

  group('rule 1: a card is a wishlist entry or a listing, never both', () {
    test('listing a wishlisted card removes it from the wishlist', () {
      final state = _draft().toggleListing('wish-any').stateOf('wish-any');
      expect(state, isA<Listed>());
    });

    test('wishlisting a listed card removes the listing', () {
      final state = _draft().toggleWishlist('listed').stateOf('listed');
      expect(state, isA<Wishlisted>());
    });

    test('toggling the same kind again turns the card off', () {
      final draft = _draft().toggleWishlist('new').toggleWishlist('new');
      expect(draft.stateOf('new'), isA<NotInCollection>());
      expect(_draft().toggleListing('listed').stateOf('listed'),
          isA<NotInCollection>());
    });
  });

  group('rule 2: "any language" or specific languages, never both', () {
    test('adding a specific language to "any language" drops "any"', () {
      final draft = _draft().setLanguages('wish-any', {'ANY', 'JPN'});
      _expectWishlisted(draft.stateOf('wish-any'), {'JPN'});
    });

    test('adding "any language" to specific languages keeps only "any"', () {
      final draft =
          _draft().setLanguages('wish-jpn-fra', {'FRA', 'JPN', 'ANY'});
      _expectWishlisted(draft.stateOf('wish-jpn-fra'), {'ANY'});
    });

    test('several specific languages are allowed', () {
      final draft = _draft().setLanguages('wish-any', {'ENG', 'KOR'});
      _expectWishlisted(draft.stateOf('wish-any'), {'ENG', 'KOR'});
    });

    test('an empty choice keeps the current languages', () {
      final draft = _draft().setLanguages('wish-jpn-fra', {});
      _expectWishlisted(draft.stateOf('wish-jpn-fra'), {'FRA', 'JPN'});
    });

    test('a wishlist entry offers multi-select with "any language"', () {
      expect(_draft().languageChoicesFor('wish-any'),
          LanguageChoices.anyOrSeveral);
    });
  });

  group('rule 3: a listing has exactly one specific language', () {
    test('choosing another language replaces the current one', () {
      final draft = _draft().setLanguages('listed', {'FRA', 'KOR'});
      _expectListed(draft.stateOf('listed'), 'KOR',
          tradeConditions: [_condition]);
    });

    test('"any language" is ignored for a listing', () {
      final draft = _draft().setLanguages('listed', {'ANY'});
      _expectListed(draft.stateOf('listed'), 'FRA',
          tradeConditions: [_condition]);
    });

    test('a listing offers a single specific language', () {
      expect(
          _draft().languageChoicesFor('listed'), LanguageChoices.oneSpecific);
    });

    test('a card not in the collection offers no language choice', () {
      expect(_draft().languageChoicesFor('unknown'), isNull);
    });

    test('setting languages on a card not in the collection does nothing', () {
      final draft = _draft().setLanguages('unknown', {'ENG'});
      expect(draft.stateOf('unknown'), isA<NotInCollection>());
      expect(draft.hasChanges, isFalse);
    });
  });

  group('rule 4: defaults', () {
    test('a new wishlist entry starts as "any language"', () {
      final draft = _draft().toggleWishlist('new');
      _expectWishlisted(draft.stateOf('new'), {'ANY'});
    });

    test('a new listing starts in the preferred language', () {
      _expectListed(_draft().toggleListing('new').stateOf('new'), 'ENG');
      _expectListed(
        _draft(preferredLanguage: 'DEU').toggleListing('new').stateOf('new'),
        'DEU',
      );
    });
  });

  group('rule 5: switching between wishlist entry and listing', () {
    test('wishlist to listing keeps the first specific language', () {
      final draft = _draft().toggleListing('wish-jpn-fra');
      // JPN comes before FRA in the app's language order.
      _expectListed(draft.stateOf('wish-jpn-fra'), 'JPN');
    });

    test('wishlist in "any language" to listing uses the preferred language',
        () {
      final draft =
          _draft(preferredLanguage: 'ITA').toggleListing('wish-any');
      _expectListed(draft.stateOf('wish-any'), 'ITA');
    });

    test('listing to wishlist carries the listing language over', () {
      final draft = _draft().toggleWishlist('listed');
      _expectWishlisted(draft.stateOf('listed'), {'FRA'});
    });
  });

  group('rule 6: off and back on restores the saved state', () {
    test('a listing comes back with its language and trade conditions', () {
      final draft = _draft()
          .setLanguages('listed', {'KOR'})
          .toggleListing('listed')
          .toggleListing('listed');
      _expectListed(draft.stateOf('listed'), 'FRA',
          tradeConditions: [_condition]);
      expect(draft.hasChanges, isFalse);
    });

    test('a listing switched to the wishlist and back is restored', () {
      final draft = _draft().toggleWishlist('listed').toggleListing('listed');
      _expectListed(draft.stateOf('listed'), 'FRA',
          tradeConditions: [_condition]);
      expect(draft.changes, isEmpty);
    });

    test('a wishlist entry comes back with its languages', () {
      final draft = _draft()
          .toggleWishlist('wish-jpn-fra')
          .toggleWishlist('wish-jpn-fra');
      _expectWishlisted(draft.stateOf('wish-jpn-fra'), {'FRA', 'JPN'});
      expect(draft.hasChanges, isFalse);
    });
  });

  group('rule 7: trade conditions belong to a listing', () {
    test('a listing that becomes a wishlist entry loses them', () {
      final draft = _draft().toggleWishlist('listed');
      expect(draft.changes['listed'], isA<Wishlisted>());
      expect(draft.isTradeConditionTarget('A1-002'), isFalse);
    });

    test('a removed listing loses them', () {
      final draft = _draft().toggleListing('listed');
      expect(draft.changes['listed'], isA<NotInCollection>());
      expect(draft.isTradeConditionTarget('A1-002'), isFalse);
    });

    test('a language change keeps them', () {
      final draft = _draft().setLanguages('listed', {'ENG'});
      _expectListed(draft.changes['listed']!, 'ENG',
          tradeConditions: [_condition]);
    });

    test('they can be replaced on a listing', () {
      final replacement = [
        TradeCondition(cardId: 'A1-003', languages: {'JPN'}),
      ];
      final draft = _draft().setTradeConditions('listed', replacement);
      _expectListed(draft.stateOf('listed'), 'FRA',
          tradeConditions: replacement);
      expect(draft.isTradeConditionTarget('A1-003'), isTrue);
      expect(draft.isTradeConditionTarget('A1-002'), isFalse);
    });

    test('they cannot be set on a card that is not a listing', () {
      final draft = _draft().setTradeConditions('wish-any', [_condition]);
      _expectWishlisted(draft.stateOf('wish-any'), {'ANY'});
      expect(draft.hasChanges, isFalse);
    });
  });

  group('changes', () {
    test('are the desired state of each changed card only', () {
      final draft = _draft()
          .toggleWishlist('new')
          .toggleListing('wish-any')
          .setLanguages('wish-jpn-fra', {'FRA', 'JPN'});
      expect(draft.changes.keys, unorderedEquals(['new', 'wish-any']));
      _expectWishlisted(draft.changes['new']!, {'ANY'});
      _expectListed(draft.changes['wish-any']!, 'ENG');
    });

    test('a card set back to its saved state produces no change', () {
      final draft = _draft()
          .setLanguages('listed', {'KOR'})
          .setLanguages('listed', {'FRA'});
      expect(draft.hasChanges, isFalse);
    });

    test('a removed card is a change to "not in the collection"', () {
      final draft = _draft().toggleWishlist('wish-any');
      expect(draft.hasChanges, isTrue);
      expect(draft.changes['wish-any'], isA<NotInCollection>());
    });

    test('discard drops every change', () {
      final draft = _draft()
          .toggleWishlist('new')
          .toggleListing('listed')
          .discard();
      expect(draft.hasChanges, isFalse);
      expect(draft.stateOf('new'), isA<NotInCollection>());
      _expectListed(draft.stateOf('listed'), 'FRA',
          tradeConditions: [_condition]);
    });

    test('intents leave the original draft unchanged', () {
      final original = _draft();
      original.toggleWishlist('new');
      expect(original.hasChanges, isFalse);
    });
  });

  test('setting trade conditions and then unlisting changes only the listing',
      () {
    final draft = _draft()
        .setTradeConditions('listed', [
          TradeCondition(cardId: 'A1-003', languages: {'ANY'}),
        ])
        .toggleListing('listed');
    expect(draft.changes, {'listed': const NotInCollection()});
    expect(draft.isTradeConditionTarget('A1-003'), isFalse);
  });

  group('rebasedOn', () {
    test('keeps unsaved changes on top of a newly loaded collection', () {
      final draft = CollectionDraft(Collection())
          .toggleWishlist('new')
          .rebasedOn(_saved);
      _expectWishlisted(draft.stateOf('new'), {'ANY'});
      _expectListed(draft.stateOf('listed'), 'FRA',
          tradeConditions: [_condition]);
      expect(draft.changes.keys, ['new']);
    });

    test('drops changes made to a card whose saved state changed', () {
      // Wanted before the collection loaded, but the card is a listing.
      final draft = CollectionDraft(Collection())
          .toggleWishlist('listed')
          .rebasedOn(_saved);
      expect(draft.hasChanges, isFalse);
      _expectListed(draft.stateOf('listed'), 'FRA',
          tradeConditions: [_condition]);
    });

    test('drops changes to cards the new collection no longer has', () {
      final draft = _draft().toggleListing('listed').rebasedOn(Collection());
      expect(draft.hasChanges, isFalse);
      expect(draft.stateOf('listed'), isA<NotInCollection>());
    });

    test('drops changes the new collection already has', () {
      final draft = CollectionDraft(Collection())
          .toggleWishlist('wish-any')
          .rebasedOn(_saved);
      expect(draft.hasChanges, isFalse);
    });

    test('restores toggled cards to the new saved state', () {
      final draft = CollectionDraft(Collection())
          .rebasedOn(_saved)
          .toggleListing('listed')
          .toggleListing('listed');
      _expectListed(draft.stateOf('listed'), 'FRA',
          tradeConditions: [_condition]);
    });

    test('keeps the preferred language', () {
      final draft = CollectionDraft(Collection(), preferredLanguage: 'KOR')
          .rebasedOn(_saved);
      expect(draft.preferredLanguage, 'KOR');
    });
  });

  test('trade-condition targets include unsaved listings', () {
    final draft = _draft()
        .toggleListing('new')
        .setTradeConditions('new', [
      TradeCondition(cardId: 'A1-009', languages: {'ANY'}),
    ]);
    expect(draft.isTradeConditionTarget('A1-009'), isTrue);
    expect(draft.isTradeConditionTarget('A1-002'), isTrue);
    expect(draft.isTradeConditionTarget('listed'), isFalse);
  });

  test('the saved collection with the changes applied', () {
    final draft = _draft().toggleWishlist('listed').toggleListing('new');
    final applied = _saved.withChanges(draft.changes);
    expect(applied.isWishlisted('listed', language: 'FRA'), isTrue);
    expect(applied.isListed('listed'), isFalse);
    expect(applied.isListed('new', language: 'ENG'), isTrue);
    expect(applied.isTradeConditionTarget('A1-002'), isFalse);
    expect(applied.isWishlisted('wish-any'), isTrue);
  });
}
