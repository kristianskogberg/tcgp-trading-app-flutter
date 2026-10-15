import 'package:flutter/foundation.dart';
import 'package:tcgp_trading_app/collection/collection.dart';
import 'package:tcgp_trading_app/collection/collection_draft.dart';
import 'package:tcgp_trading_app/trading/trade_match.dart';

/// What the trade preview can offer to add to the user's collection so a
/// partial match's proposal is backed by it: a listing for the card they
/// send and a wishlist entry for the card they receive.
///
/// Nothing is offered that would remove something from the collection: a
/// card already wishlisted isn't offered as a listing, and the other way
/// round.
@immutable
class MatchCompletion {
  final TradeMatch _match;

  /// The listing to offer for the card the user sends, or null. Always in a
  /// specific language: the preferred language when the other player
  /// accepts any.
  final TradeSide? listing;

  /// The wishlist entry to offer for the card the user receives, or null.
  final TradeSide? wishlistEntry;

  const MatchCompletion._(this._match, {this.listing, this.wishlistEntry});

  factory MatchCompletion.of(
    TradeMatch match,
    Collection collection, {
    required String preferredLanguage,
  }) {
    bool isNew(TradeSide side) =>
        collection.stateOf(side.card.id) is NotInCollection;

    final sent = match.send;
    return MatchCompletion._(
      match,
      listing: isNew(sent)
          ? TradeSide(
              sent.card,
              sent.language == anyLanguage ? preferredLanguage : sent.language,
            )
          : null,
      wishlistEntry: isNew(match.receive) ? match.receive : null,
    );
  }

  /// [draft] with the offered [listing] and [wishlistEntry] added where
  /// chosen.
  CollectionDraft addTo(
    CollectionDraft draft, {
    required bool addListing,
    required bool addWishlistEntry,
  }) {
    var result = draft;
    if (listing case final side? when addListing) {
      result = result
          .toggleListing(side.card.id)
          .setLanguages(side.card.id, {side.language});
    }
    if (wishlistEntry case final side? when addWishlistEntry) {
      result = result
          .toggleWishlist(side.card.id)
          .setLanguages(side.card.id, {side.language});
    }
    return result;
  }

  /// The trade match to propose. Once the offered [listing] is added, the
  /// card is sent in its language rather than "any language".
  TradeMatch proposal({required bool listingAdded}) {
    final added = listing;
    if (!listingAdded || added == null) return _match;
    return TradeMatch(
      userId: _match.userId,
      playerName: _match.playerName,
      friendId: _match.friendId,
      icon: _match.icon,
      lastActiveAt: _match.lastActiveAt,
      send: added,
      receive: _match.receive,
      direction: _match.direction,
      isPerfect: _match.isPerfect,
      hasPendingProposal: _match.hasPendingProposal,
    );
  }
}
