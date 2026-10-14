import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tcgp_trading_app/collection/collection.dart';
import 'package:tcgp_trading_app/collection/collection_rows.dart';

void main() {
  group('collectionFromRows', () {
    test('wishlist rows for one card become one entry with all its languages',
        () {
      final collection = collectionFromRows(
        cardRows: [
          {'card_id': 'A1-001', 'type': 'wishlist', 'language': 'ENG'},
          {'card_id': 'A1-001', 'type': 'wishlist', 'language': 'JPN'},
        ],
        conditionRows: [],
      );

      expect(collection.wishlistEntryFor('A1-001')!.languages, {'ENG', 'JPN'});
      expect(collection.listingFor('A1-001'), isNull);
    });

    test('a listing row carries the trade conditions set on it', () {
      final collection = collectionFromRows(
        cardRows: [
          {'card_id': 'A1-002', 'type': 'listing', 'language': 'JPN'},
        ],
        conditionRows: [
          {
            'listed_card_id': 'A1-002',
            'wanted_card_id': 'A1-010',
            'wanted_language': 'ENG',
          },
          {
            'listed_card_id': 'A1-002',
            'wanted_card_id': 'A1-010',
            'wanted_language': 'FRA',
          },
          {
            'listed_card_id': 'A1-002',
            'wanted_card_id': 'A1-011',
            'wanted_language': null,
          },
        ],
      );

      final listing = collection.listingFor('A1-002')!;
      expect(listing.language, 'JPN');
      expect(
        {for (final c in listing.tradeConditions) c.cardId: c.languages},
        {
          'A1-010': {'ENG', 'FRA'},
          'A1-011': {'ANY'},
        },
      );
      expect(collection.wishlistEntryFor('A1-002'), isNull);
    });

    test('a card listed in several languages becomes one listing', () {
      final collection = collectionFromRows(
        cardRows: [
          {'card_id': 'A1-004', 'type': 'listing', 'language': 'ENG'},
          {'card_id': 'A1-004', 'type': 'listing', 'language': 'JPN'},
        ],
        conditionRows: [],
      );

      expect(collection.listings.single.language, 'ENG');
    });

    test('rows with an unknown type are ignored', () {
      final collection = collectionFromRows(
        cardRows: [
          {'card_id': 'A1-005', 'type': 'owned', 'language': 'ENG'},
        ],
        conditionRows: [],
      );

      expect(collection.wishlist, isEmpty);
      expect(collection.listings, isEmpty);
    });

    test('trade conditions on a card that is not a listing are dropped', () {
      final collection = collectionFromRows(
        cardRows: [
          {'card_id': 'A1-003', 'type': 'wishlist', 'language': 'ANY'},
        ],
        conditionRows: [
          {
            'listed_card_id': 'A1-003',
            'wanted_card_id': 'A1-010',
            'wanted_language': 'ENG',
          },
        ],
      );

      expect(collection.isTradeConditionTarget('A1-010'), isFalse);
    });
  });

  test('a collection survives a round trip through the device cache', () {
    final cached = collectionToCache(Collection(
      wishlist: [
        WishlistEntry(cardId: 'A1-001', languages: {'ENG', 'JPN'}),
      ],
      listings: [
        Listing(cardId: 'A1-002', language: 'FRA', tradeConditions: [
          TradeCondition(cardId: 'A1-010', languages: {'ANY'}),
        ]),
      ],
    ));

    final restored = collectionFromCache(jsonDecode(jsonEncode(cached)));

    expect(restored.wishlistEntryFor('A1-001')!.languages, {'ENG', 'JPN'});
    final listing = restored.listingFor('A1-002')!;
    expect(listing.language, 'FRA');
    expect(listing.tradeConditions.single.cardId, 'A1-010');
    expect(listing.tradeConditions.single.languages, {'ANY'});
  });
}
