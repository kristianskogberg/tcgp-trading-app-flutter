import 'package:flutter/foundation.dart';
import 'package:tcgp_trading_app/models/card.dart';

/// Which side of a trade match the viewed card is on.
enum TradeDirection {
  /// The user would receive the viewed card.
  receiving,

  /// The user would send the viewed card.
  sending,
}

/// A pending trade proposal the user sent: to [otherUserId], sending
/// [sendCardId] for [receiveCardId].
typedef ProposalKey = ({
  String otherUserId,
  String sendCardId,
  String receiveCardId,
});

/// One card of a trade match, in the card language it changes hands in.
/// The sent card may be in "any language" when the other player accepts any.
@immutable
class TradeSide {
  final PocketCard card;
  final String language;

  const TradeSide(this.card, this.language);
}

/// A trade match as the source returns it: card ids, not yet joined to the
/// card catalog.
@immutable
class TradeMatchRow {
  final String userId;
  final String playerName;
  final String friendId;
  final String? icon;
  final DateTime? lastActiveAt;
  final String sendCardId;
  final String sendLanguage;
  final String receiveCardId;
  final String receiveLanguage;
  final bool isPerfect;

  const TradeMatchRow({
    required this.userId,
    required this.playerName,
    this.friendId = '',
    this.icon,
    this.lastActiveAt,
    required this.sendCardId,
    required this.sendLanguage,
    required this.receiveCardId,
    required this.receiveLanguage,
    this.isPerfect = false,
  });
}

/// Another player the user could trade with: the user sends [send] and
/// receives [receive]. See "Trade match" in CONTEXT.md.
@immutable
class TradeMatch {
  final String userId;
  final String playerName;
  final String friendId;
  final String? icon;
  final DateTime? lastActiveAt;
  final TradeSide send;
  final TradeSide receive;

  /// Which side the viewed card is on.
  final TradeDirection direction;

  /// Whether the user's own collection also allows the swap: they list the
  /// card they send and wishlist the card they receive.
  final bool isPerfect;

  /// Whether the user already sent this player this exact proposal.
  final bool hasPendingProposal;

  const TradeMatch({
    required this.userId,
    required this.playerName,
    required this.friendId,
    this.icon,
    this.lastActiveAt,
    required this.send,
    required this.receive,
    required this.direction,
    required this.isPerfect,
    this.hasPendingProposal = false,
  });

  /// The side that isn't the viewed card: the one shown in the grid.
  TradeSide get other => switch (direction) {
        TradeDirection.receiving => send,
        TradeDirection.sending => receive,
      };

  PocketCard get otherCard => other.card;

  ProposalKey get proposalKey => (
        otherUserId: userId,
        sendCardId: send.card.id,
        receiveCardId: receive.card.id,
      );

  TradeMatch withPendingProposal(bool value) => TradeMatch(
        userId: userId,
        playerName: playerName,
        friendId: friendId,
        icon: icon,
        lastActiveAt: lastActiveAt,
        send: send,
        receive: receive,
        direction: direction,
        isPerfect: isPerfect,
        hasPendingProposal: value,
      );
}

/// The filter a Trade match feed applies, in the source.
@immutable
class TradeMatchFilter {
  /// Card languages of the other card, as the other player declared them.
  /// Empty means every language.
  final Set<String> languages;

  /// Only full-art trainer cards.
  final bool fullArtOnly;

  /// Receiving: only cards the user lists. Sending: only cards the user
  /// wishlists.
  final bool onlyMine;

  TradeMatchFilter({
    Set<String> languages = const {},
    this.fullArtOnly = false,
    this.onlyMine = false,
  }) : languages = Set.unmodifiable(languages);

  TradeMatchFilter copyWith({
    Set<String>? languages,
    bool? fullArtOnly,
    bool? onlyMine,
  }) =>
      TradeMatchFilter(
        languages: languages ?? this.languages,
        fullArtOnly: fullArtOnly ?? this.fullArtOnly,
        onlyMine: onlyMine ?? this.onlyMine,
      );
}
