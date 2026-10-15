import 'package:tcgp_trading_app/collection/collection.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/trading/trade_match.dart';
import 'package:tcgp_trading_app/trading/trade_match_source.dart';

/// A [TradeMatchSource] over a fixed list of rows, for tests. It filters by
/// the viewed card, the direction and the language filter only; the rows are
/// returned in the order given.
class InMemoryTradeMatchSource implements TradeMatchSource {
  final List<TradeMatchRow> rows;
  Set<ProposalKey> proposals;

  /// When set, every fetch throws it.
  Object? error;

  /// When set, every fetch waits for it before answering.
  Future<void> Function()? gate;

  InMemoryTradeMatchSource({
    this.rows = const [],
    Set<ProposalKey>? proposals,
  }) : proposals = proposals ?? {};

  @override
  Future<List<TradeMatchRow>> fetchPage(
    PocketCard card,
    TradeDirection direction,
    TradeMatchFilter filter, {
    required int offset,
    required int limit,
  }) async {
    await gate?.call();
    if (error case final e?) throw e;
    return rows
        .where((r) => switch (direction) {
              TradeDirection.receiving => r.receiveCardId == card.id,
              TradeDirection.sending => r.sendCardId == card.id,
            })
        .where((r) {
          if (filter.languages.isEmpty) return true;
          final language = switch (direction) {
            TradeDirection.receiving => r.sendLanguage,
            TradeDirection.sending => r.receiveLanguage,
          };
          return language == anyLanguage ||
              filter.languages.contains(language);
        })
        .skip(offset)
        .take(limit)
        .toList();
  }

  @override
  Future<Set<ProposalKey>> pendingProposals() async => {...proposals};
}
