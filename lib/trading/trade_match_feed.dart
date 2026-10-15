import 'package:flutter/foundation.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/trading/trade_match.dart';
import 'package:tcgp_trading_app/trading/trade_match_source.dart';

/// What a [TradeMatchFeed] shows at one moment.
@immutable
class TradeMatchFeedState {
  /// The matches loaded so far, perfect matches first.
  final List<TradeMatch> matches;

  /// Loading the first page.
  final bool isLoading;

  /// Loading the next page.
  final bool isLoadingMore;

  /// Whether the source may have more matches after [matches].
  final bool hasMore;

  /// Why the last fetch failed, or null. [matches] keeps the pages loaded
  /// before it.
  final Object? error;

  const TradeMatchFeedState({
    this.matches = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });
}

/// The trade matches for one card in one direction, loaded page by page
/// from a [TradeMatchSource] and joined to the card catalog.
class TradeMatchFeed extends ChangeNotifier {
  final PocketCard card;
  final TradeDirection direction;
  final TradeMatchSource _source;

  /// The card catalog by id. It may wait for the catalog to load; matches
  /// whose card isn't in it are dropped.
  final Future<Map<String, PocketCard>> Function() _catalog;
  final int pageSize;
  TradeMatchFilter _filter;

  TradeMatchFeed({
    required this.card,
    required this.direction,
    required TradeMatchSource source,
    required Future<Map<String, PocketCard>> Function() catalog,
    TradeMatchFilter? filter,
    this.pageSize = 30,
  })  : _source = source,
        _catalog = catalog,
        _filter = filter ?? TradeMatchFilter();

  TradeMatchFeedState _state = const TradeMatchFeedState();
  TradeMatchFeedState get state => _state;

  TradeMatchFilter get filter => _filter;

  /// How many rows the source has returned so far; the next page's offset.
  int _offset = 0;

  Set<ProposalKey> _proposals = {};

  /// Bumped by every [load]; a response for an older generation is stale.
  int _generation = 0;

  bool _disposed = false;

  /// Loads the first page, dropping any pages loaded before.
  Future<void> load() async {
    final generation = ++_generation;
    _offset = 0;
    _setState(const TradeMatchFeedState(isLoading: true));
    try {
      final (rows, cards, proposals) = await (
        _source.fetchPage(card, direction, _filter,
            offset: 0, limit: pageSize),
        _catalog(),
        _source.pendingProposals(),
      ).wait;
      if (generation != _generation) return;
      _proposals = proposals;
      _offset = rows.length;
      _setState(TradeMatchFeedState(
        matches: _join(rows, cards),
        hasMore: rows.length >= pageSize,
      ));
    } catch (e) {
      if (generation != _generation) return;
      debugPrint('Failed to load trade matches: $e');
      _setState(TradeMatchFeedState(hasMore: false, error: e));
    }
  }

  /// Appends the next page. Does nothing while a page is loading or when
  /// there is no more; after a failed page it retries that page.
  Future<void> loadMore() async {
    if (_state.isLoading || _state.isLoadingMore || !_state.hasMore) return;
    final generation = _generation;
    _setState(_copyState(isLoadingMore: true, error: null));
    try {
      final (rows, cards) = await (
        _source.fetchPage(card, direction, _filter,
            offset: _offset, limit: pageSize),
        _catalog(),
      ).wait;
      if (generation != _generation) return;
      _offset += rows.length;
      _setState(_copyState(
        matches: [..._state.matches, ..._join(rows, cards)],
        isLoadingMore: false,
        hasMore: rows.length >= pageSize,
      ));
    } catch (e) {
      if (generation != _generation) return;
      debugPrint('Failed to load more trade matches: $e');
      _setState(_copyState(isLoadingMore: false, error: e));
    }
  }

  /// Re-reads the user's pending trade proposals and re-flags the loaded
  /// matches, e.g. after the user sent one. Keeps the old flags if it fails.
  Future<void> refreshProposals() async {
    final Set<ProposalKey> proposals;
    try {
      proposals = await _source.pendingProposals();
    } catch (e) {
      debugPrint('Failed to refresh pending trade proposals: $e');
      return;
    }
    _proposals = proposals;
    _setState(_copyState(matches: [
      for (final m in _state.matches)
        m.withPendingProposal(proposals.contains(m.proposalKey)),
    ]));
  }

  /// Applies [filter] and loads its first page; pages loaded or loading for
  /// the old filter are dropped.
  Future<void> setFilter(TradeMatchFilter filter) {
    _filter = filter;
    return load();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _setState(TradeMatchFeedState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  TradeMatchFeedState _copyState({
    List<TradeMatch>? matches,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error = _keep,
  }) =>
      TradeMatchFeedState(
        matches: matches ?? _state.matches,
        isLoading: _state.isLoading,
        isLoadingMore: isLoadingMore ?? _state.isLoadingMore,
        hasMore: hasMore ?? _state.hasMore,
        error: identical(error, _keep) ? _state.error : error,
      );

  static const _keep = Object();

  List<TradeMatch> _join(
      List<TradeMatchRow> rows, Map<String, PocketCard> cards) {
    final matches = <TradeMatch>[];
    for (final r in rows) {
      final send = cards[r.sendCardId];
      final receive = cards[r.receiveCardId];
      if (send == null || receive == null) continue;
      final match = TradeMatch(
        userId: r.userId,
        playerName: r.playerName,
        friendId: r.friendId,
        icon: r.icon,
        lastActiveAt: r.lastActiveAt,
        send: TradeSide(send, r.sendLanguage),
        receive: TradeSide(receive, r.receiveLanguage),
        direction: direction,
        isPerfect: r.isPerfect,
      );
      matches.add(
          match.withPendingProposal(_proposals.contains(match.proposalKey)));
    }
    return matches;
  }
}
