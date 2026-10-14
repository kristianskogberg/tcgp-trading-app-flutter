import 'package:flutter/foundation.dart';

/// The card language code that matches every specific language.
const anyLanguage = 'ANY';

/// Whether a collection item is a wishlist entry or a listing.
enum CollectionItemKind {
  wishlist,
  listing,
}

bool _languagesMatch(String a, String b) =>
    a == anyLanguage || b == anyLanguage || a == b;

/// A card the user wants to receive, in "any language" or one or more
/// specific languages.
@immutable
class WishlistEntry {
  final String cardId;
  final Set<String> languages;

  WishlistEntry({required this.cardId, required Set<String> languages})
      : languages = Set.unmodifiable(languages);
}

/// A card the owner of a listing will accept in exchange for it, in "any
/// language" or specific languages.
@immutable
class TradeCondition {
  final String cardId;
  final Set<String> languages;

  TradeCondition({required this.cardId, required Set<String> languages})
      : languages = Set.unmodifiable(languages);
}

/// Whether [a] and [b] accept the same cards in the same languages, in any
/// order.
bool sameTradeConditions(List<TradeCondition> a, List<TradeCondition> b) {
  if (a.length != b.length) return false;
  final bLanguages = {for (final c in b) c.cardId: c.languages};
  return a.every((c) {
    final other = bLanguages[c.cardId];
    return other != null && setEquals(c.languages, other);
  });
}

/// A card the user offers to trade away, in exactly one specific language.
/// A listing with no trade conditions accepts any card.
@immutable
class Listing {
  final String cardId;
  final String language;
  final List<TradeCondition> tradeConditions;

  Listing({
    required this.cardId,
    required this.language,
    List<TradeCondition> tradeConditions = const [],
  }) : tradeConditions = List.unmodifiable(tradeConditions);
}

/// What one card is in a collection: not in it, a wishlist entry or a listing.
/// Two states are equal when they describe the same card in the same
/// languages with the same trade conditions.
@immutable
sealed class CardState {
  const CardState();

  /// The card's languages, or none if it isn't in the collection.
  Set<String> get languages;

  /// The trade conditions of a listing, or none for any other card.
  List<TradeCondition> get tradeConditions;
}

final class NotInCollection extends CardState {
  const NotInCollection();

  @override
  Set<String> get languages => const {};

  @override
  List<TradeCondition> get tradeConditions => const [];

  @override
  bool operator ==(Object other) => other is NotInCollection;

  @override
  int get hashCode => (NotInCollection).hashCode;
}

final class Wishlisted extends CardState {
  @override
  final Set<String> languages;

  Wishlisted(Set<String> languages) : languages = Set.unmodifiable(languages);

  @override
  List<TradeCondition> get tradeConditions => const [];

  @override
  bool operator ==(Object other) =>
      other is Wishlisted && setEquals(languages, other.languages);

  @override
  int get hashCode => Object.hashAllUnordered(languages);
}

final class Listed extends CardState {
  final String language;
  @override
  final List<TradeCondition> tradeConditions;

  Listed(this.language, {List<TradeCondition> tradeConditions = const []})
      : tradeConditions = List.unmodifiable(tradeConditions);

  @override
  Set<String> get languages => {language};

  @override
  bool operator ==(Object other) =>
      other is Listed &&
      language == other.language &&
      sameTradeConditions(tradeConditions, other.tradeConditions);

  @override
  int get hashCode => language.hashCode;
}

/// Everything one user has declared about cards: their wishlist entries and
/// their listings. A card should be either a wishlist entry or a listing, never
/// both; the Collection draft enforces that for edits.
@immutable
class Collection {
  final Map<String, WishlistEntry> _wishlist;
  final Map<String, Listing> _listings;

  Collection({
    Iterable<WishlistEntry> wishlist = const [],
    Iterable<Listing> listings = const [],
  })  : _wishlist = {for (final e in wishlist) e.cardId: e},
        _listings = {for (final l in listings) l.cardId: l};

  Iterable<WishlistEntry> get wishlist => _wishlist.values;

  Iterable<Listing> get listings => _listings.values;

  WishlistEntry? wishlistEntryFor(String cardId) => _wishlist[cardId];

  Listing? listingFor(String cardId) => _listings[cardId];

  /// Whether [cardId] is on the wishlist. With a [language], the entry must
  /// match it, where "any language" on either side matches everything.
  bool isWishlisted(String cardId, {String? language}) {
    final entry = _wishlist[cardId];
    if (entry == null) return false;
    if (language == null) return true;
    return entry.languages.any((l) => _languagesMatch(l, language));
  }

  /// Whether [cardId] is listed. With a [language], the listing must match
  /// it, where "any language" matches everything.
  bool isListed(String cardId, {String? language}) {
    final listing = _listings[cardId];
    if (listing == null) return false;
    if (language == null) return true;
    return _languagesMatch(listing.language, language);
  }

  /// The trade conditions on [cardId]'s listing, or none if it isn't listed.
  List<TradeCondition> tradeConditionsOf(String cardId) =>
      _listings[cardId]?.tradeConditions ?? const [];

  /// The languages [cardId] has as a [kind], or an empty set if it isn't one.
  Set<String> languagesOf(String cardId, CollectionItemKind kind) =>
      switch (kind) {
        CollectionItemKind.wishlist => _wishlist[cardId]?.languages ?? {},
        CollectionItemKind.listing =>
          {if (_listings[cardId] case final l?) l.language},
      };

  /// The state of [cardId]. A card stored as both a listing and a wishlist
  /// entry reads as the listing.
  CardState stateOf(String cardId) {
    if (_listings[cardId] case final l?) {
      return Listed(l.language, tradeConditions: l.tradeConditions);
    }
    if (_wishlist[cardId] case final e?) return Wishlisted(e.languages);
    return const NotInCollection();
  }

  /// The collection with each card in [changes] replaced by its new state.
  Collection withChanges(Map<String, CardState> changes) {
    final wishlist = {..._wishlist};
    final listings = {..._listings};
    for (final MapEntry(key: cardId, value: state) in changes.entries) {
      wishlist.remove(cardId);
      listings.remove(cardId);
      switch (state) {
        case NotInCollection():
          break;
        case Wishlisted(:final languages):
          wishlist[cardId] = WishlistEntry(cardId: cardId, languages: languages);
        case Listed(:final language, :final tradeConditions):
          listings[cardId] = Listing(
            cardId: cardId,
            language: language,
            tradeConditions: tradeConditions,
          );
      }
    }
    return _copy(wishlist: wishlist, listings: listings);
  }

  Collection _copy({
    Map<String, WishlistEntry>? wishlist,
    Map<String, Listing>? listings,
  }) =>
      Collection(
        wishlist: (wishlist ?? _wishlist).values,
        listings: (listings ?? _listings).values,
      );

  /// Whether [cardId] is a trade condition on any of the user's listings.
  bool isTradeConditionTarget(String cardId) => _listings.values
      .any((l) => l.tradeConditions.any((c) => c.cardId == cardId));
}
