import 'package:flutter_test/flutter_test.dart';
import 'package:tcgp_trading_app/collection/collection.dart';

void main() {
  group('language matching', () {
    final collection = Collection(
      wishlist: [
        WishlistEntry(cardId: 'wish-any', languages: {'ANY'}),
        WishlistEntry(cardId: 'wish-eng-jpn', languages: {'ENG', 'JPN'}),
      ],
      listings: [Listing(cardId: 'listed-fra', language: 'FRA')],
    );

    test('without a language, any entry for the card counts', () {
      expect(collection.isWishlisted('wish-eng-jpn'), isTrue);
      expect(collection.isListed('listed-fra'), isTrue);
      expect(collection.isWishlisted('listed-fra'), isFalse);
      expect(collection.isListed('wish-any'), isFalse);
    });

    test('a wishlist entry in any language matches every language', () {
      expect(collection.isWishlisted('wish-any', language: 'KOR'), isTrue);
    });

    test('specific languages only match themselves or "any language"', () {
      expect(collection.isWishlisted('wish-eng-jpn', language: 'JPN'), isTrue);
      expect(collection.isWishlisted('wish-eng-jpn', language: 'DEU'), isFalse);
      expect(collection.isWishlisted('wish-eng-jpn', language: 'ANY'), isTrue);
      expect(collection.isListed('listed-fra', language: 'FRA'), isTrue);
      expect(collection.isListed('listed-fra', language: 'ENG'), isFalse);
      expect(collection.isListed('listed-fra', language: 'ANY'), isTrue);
    });
  });

  test('trade conditions are the same regardless of order', () {
    final a = [
      TradeCondition(cardId: 'A1-010', languages: {'ENG', 'JPN'}),
      TradeCondition(cardId: 'A1-011', languages: {'ANY'}),
    ];
    final reordered = [
      TradeCondition(cardId: 'A1-011', languages: {'ANY'}),
      TradeCondition(cardId: 'A1-010', languages: {'JPN', 'ENG'}),
    ];
    final otherLanguage = [
      TradeCondition(cardId: 'A1-010', languages: {'ENG'}),
      TradeCondition(cardId: 'A1-011', languages: {'ANY'}),
    ];

    expect(sameTradeConditions(a, reordered), isTrue);
    expect(sameTradeConditions(a, otherLanguage), isFalse);
    expect(sameTradeConditions(a, a.take(1).toList()), isFalse);
  });

  group('applying a saved change', () {
    test('wishlist languages are added and removed one at a time', () {
      var collection = Collection()
          .withLanguageAdded('A1-001', CollectionItemKind.wishlist, 'ENG')
          .withLanguageAdded('A1-001', CollectionItemKind.wishlist, 'JPN');
      expect(
        collection.languagesOf('A1-001', CollectionItemKind.wishlist),
        {'ENG', 'JPN'},
      );

      collection = collection
          .withLanguageRemoved('A1-001', CollectionItemKind.wishlist, 'ENG')
          .withLanguageRemoved('A1-001', CollectionItemKind.wishlist, 'JPN');
      expect(collection.wishlistEntryFor('A1-001'), isNull);
    });

    test('a listing keeps one language and its trade conditions', () {
      final collection = Collection()
          .withLanguageAdded('A1-002', CollectionItemKind.listing, 'ENG')
          .withTradeConditions('A1-002', [
            TradeCondition(cardId: 'A1-010', languages: {'ANY'}),
          ]).withLanguageAdded('A1-002', CollectionItemKind.listing, 'JPN');

      expect(
        collection.languagesOf('A1-002', CollectionItemKind.listing),
        {'JPN'},
      );
      expect(collection.isTradeConditionTarget('A1-010'), isTrue);
    });

    test('removing a listing removes its trade conditions', () {
      final collection = Collection(listings: [
        Listing(cardId: 'A1-002', language: 'ENG', tradeConditions: [
          TradeCondition(cardId: 'A1-010', languages: {'ANY'}),
        ]),
      ]).withLanguageRemoved('A1-002', CollectionItemKind.listing, 'ENG');

      expect(collection.isListed('A1-002'), isFalse);
      expect(collection.isTradeConditionTarget('A1-010'), isFalse);
    });

    test('removing a language the listing is not in changes nothing', () {
      final collection = Collection(listings: [
        Listing(cardId: 'A1-002', language: 'ENG'),
      ]).withLanguageRemoved('A1-002', CollectionItemKind.listing, 'JPN');

      expect(collection.isListed('A1-002', language: 'ENG'), isTrue);
    });
  });
}
