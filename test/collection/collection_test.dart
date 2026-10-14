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

  group('applying saved changes', () {
    final collection = Collection(
      wishlist: [
        WishlistEntry(cardId: 'A1-001', languages: {'ENG', 'JPN'}),
      ],
      listings: [
        Listing(cardId: 'A1-002', language: 'ENG', tradeConditions: [
          TradeCondition(cardId: 'A1-010', languages: {'ANY'}),
        ]),
      ],
    );

    test('a changed card takes its new state', () {
      final changed = collection.withChanges({
        'A1-001': Listed('JPN'),
        'A1-003': Wishlisted({'ANY'}),
      });

      expect(changed.isWishlisted('A1-001'), isFalse);
      expect(changed.isListed('A1-001', language: 'JPN'), isTrue);
      expect(changed.wishlistEntryFor('A1-003')!.languages, {'ANY'});
    });

    test('a listing that is removed or wishlisted loses its trade conditions',
        () {
      for (final state in [const NotInCollection(), Wishlisted({'ENG'})]) {
        final changed = collection.withChanges({'A1-002': state});
        expect(changed.isListed('A1-002'), isFalse);
        expect(changed.isTradeConditionTarget('A1-010'), isFalse);
      }
    });

    test('cards without a change are kept', () {
      final changed = collection.withChanges({'A1-003': Listed('FRA')});
      expect(changed.wishlistEntryFor('A1-001')!.languages, {'ENG', 'JPN'});
      expect(changed.stateOf('A1-002'), collection.stateOf('A1-002'));
    });
  });
}
