import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/trading/trade_match.dart';

/// Where trade matches and the user's pending trade proposals come from.
abstract interface class TradeMatchSource {
  /// One page of the trade matches for [card] in [direction], perfect
  /// matches first.
  Future<List<TradeMatchRow>> fetchPage(
    PocketCard card,
    TradeDirection direction,
    TradeMatchFilter filter, {
    required int offset,
    required int limit,
  });

  /// The trade proposals the user sent that are still pending.
  Future<Set<ProposalKey>> pendingProposals();
}
