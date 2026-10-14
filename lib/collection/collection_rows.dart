import 'package:tcgp_trading_app/collection/collection.dart';

/// The `user_cards.type` value stored for [kind].
String typeValueOf(CollectionItemKind kind) => switch (kind) {
      CollectionItemKind.wishlist => 'wishlist',
      CollectionItemKind.listing => 'listing',
    };

/// Serialises [collection] for the on-device cache.
Map<String, dynamic> collectionToCache(Collection collection) => {
      'wishlist': [
        for (final e in collection.wishlist)
          {'cardId': e.cardId, 'languages': e.languages.toList()},
      ],
      'listings': [
        for (final l in collection.listings)
          {
            'cardId': l.cardId,
            'language': l.language,
            'tradeConditions': [
              for (final c in l.tradeConditions)
                {'cardId': c.cardId, 'languages': c.languages.toList()},
            ],
          },
      ],
    };

/// Reads a collection written by [collectionToCache].
Collection collectionFromCache(Map<String, dynamic> json) {
  Set<String> languages(dynamic list) => Set.from(list as List);
  return Collection(
    wishlist: [
      for (final e in json['wishlist'] as List)
        WishlistEntry(
          cardId: e['cardId'] as String,
          languages: languages(e['languages']),
        ),
    ],
    listings: [
      for (final l in json['listings'] as List)
        Listing(
          cardId: l['cardId'] as String,
          language: l['language'] as String,
          tradeConditions: [
            for (final c in l['tradeConditions'] as List)
              TradeCondition(
                cardId: c['cardId'] as String,
                languages: languages(c['languages']),
              ),
          ],
        ),
    ],
  );
}

/// The `p_changes` argument of the `save_collection_changes` RPC: the desired
/// state of each changed card. See supabase/save_collection_changes.sql.
List<Map<String, dynamic>> changesToSavePayload(
  Map<String, CardState> changes,
) =>
    [
      for (final MapEntry(key: cardId, value: state) in changes.entries)
        {
          'card_id': cardId,
          'wishlist': switch (state) {
            Wishlisted(:final languages) => {'languages': languages.toList()},
            _ => null,
          },
          'listing': switch (state) {
            Listed(:final language, :final tradeConditions) => {
                'languages': [language],
                'trade_conditions': [
                  for (final c in tradeConditions)
                    {'card_id': c.cardId, 'languages': c.languages.toList()},
                ],
              },
            _ => null,
          },
        },
    ];

/// Builds a [Collection] from `user_cards` and `trade_conditions` rows.
///
/// This is the only place that knows how the collection is stored in
/// Supabase: the `wishlist`/`listing` type values and the column names.
Collection collectionFromRows({
  required List<Map<String, dynamic>> cardRows,
  required List<Map<String, dynamic>> conditionRows,
}) {
  final wishlistLanguages = <String, Set<String>>{};
  final listingLanguages = <String, String>{};
  for (final row in cardRows) {
    final cardId = row['card_id'] as String;
    final language = row['language'] as String;
    if (row['type'] == typeValueOf(CollectionItemKind.wishlist)) {
      wishlistLanguages.putIfAbsent(cardId, () => {}).add(language);
    } else if (row['type'] == typeValueOf(CollectionItemKind.listing)) {
      listingLanguages.putIfAbsent(cardId, () => language);
    }
  }

  // listed card id -> wanted card id -> wanted languages
  final conditions = <String, Map<String, Set<String>>>{};
  for (final row in conditionRows) {
    conditions
        .putIfAbsent(row['listed_card_id'] as String, () => {})
        .putIfAbsent(row['wanted_card_id'] as String, () => {})
        .add((row['wanted_language'] as String?) ?? anyLanguage);
  }

  return Collection(
    wishlist: [
      for (final e in wishlistLanguages.entries)
        WishlistEntry(cardId: e.key, languages: e.value),
    ],
    listings: [
      for (final e in listingLanguages.entries)
        Listing(
          cardId: e.key,
          language: e.value,
          tradeConditions: [
            for (final c in (conditions[e.key] ?? {}).entries)
              TradeCondition(cardId: c.key, languages: c.value),
          ],
        ),
    ],
  );
}
