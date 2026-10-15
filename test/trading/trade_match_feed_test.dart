import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/trading/in_memory_trade_match_source.dart';
import 'package:tcgp_trading_app/trading/trade_match.dart';
import 'package:tcgp_trading_app/trading/trade_match_feed.dart';

PocketCard _card(String id) => PocketCard(
      id: id,
      name: 'Card $id',
      rarity: '◊',
      pack: '',
      imageUrl: '',
      type: 'Pokemon',
      cardType: '',
    );

final _viewed = _card('A1-001');
final _catalog = {
  for (final id in ['A1-001', 'A1-002', 'A1-003', 'A1-004']) id: _card(id),
};

TradeMatchRow _row({
  String userId = 'bob',
  required String send,
  String sendLanguage = 'ENG',
  required String receive,
  String receiveLanguage = 'JPN',
  bool isPerfect = false,
}) =>
    TradeMatchRow(
      userId: userId,
      playerName: 'Player $userId',
      sendCardId: send,
      sendLanguage: sendLanguage,
      receiveCardId: receive,
      receiveLanguage: receiveLanguage,
      isPerfect: isPerfect,
    );

/// [count] receiving rows for the viewed card, one per other player.
List<TradeMatchRow> _receivingRows(int count) => [
      for (var i = 0; i < count; i++)
        _row(userId: 'user$i', send: 'A1-002', receive: _viewed.id),
    ];

TradeMatchFeed _feed(
  InMemoryTradeMatchSource source, {
  TradeDirection direction = TradeDirection.receiving,
  Future<Map<String, PocketCard>> Function()? catalog,
  int pageSize = 30,
}) =>
    TradeMatchFeed(
      card: _viewed,
      direction: direction,
      source: source,
      catalog: catalog ?? () async => _catalog,
      pageSize: pageSize,
    );

void main() {
  group('direction', () {
    test('receiving: the user receives the viewed card', () async {
      final feed = _feed(InMemoryTradeMatchSource(rows: [
        _row(
          send: 'A1-002',
          sendLanguage: 'ANY',
          receive: 'A1-001',
          receiveLanguage: 'JPN',
          isPerfect: true,
        ),
      ]));
      await feed.load();

      final match = feed.state.matches.single;
      expect(match.receive.card.id, 'A1-001');
      expect(match.receive.language, 'JPN');
      expect(match.send.card.id, 'A1-002');
      expect(match.send.language, 'ANY');
      expect(match.otherCard.id, 'A1-002');
      expect(match.isPerfect, isTrue);
      expect(match.playerName, 'Player bob');
    });

    test('sending: the user sends the viewed card', () async {
      final feed = _feed(
        InMemoryTradeMatchSource(rows: [
          _row(
            send: 'A1-001',
            sendLanguage: 'ENG',
            receive: 'A1-003',
            receiveLanguage: 'KOR',
          ),
        ]),
        direction: TradeDirection.sending,
      );
      await feed.load();

      final match = feed.state.matches.single;
      expect(match.send.card.id, 'A1-001');
      expect(match.send.language, 'ENG');
      expect(match.receive.card.id, 'A1-003');
      expect(match.receive.language, 'KOR');
      expect(match.otherCard.id, 'A1-003');
      expect(match.isPerfect, isFalse);
    });
  });

  group('paging', () {
    test('loads the first page, then appends the next', () async {
      final feed =
          _feed(InMemoryTradeMatchSource(rows: _receivingRows(5)), pageSize: 2);

      final loading = feed.load();
      expect(feed.state.isLoading, isTrue);
      await loading;
      expect(feed.state.isLoading, isFalse);
      expect(feed.state.matches.map((m) => m.userId), ['user0', 'user1']);
      expect(feed.state.hasMore, isTrue);

      final loadingMore = feed.loadMore();
      expect(feed.state.isLoadingMore, isTrue);
      await loadingMore;
      expect(feed.state.isLoadingMore, isFalse);
      expect(feed.state.matches.map((m) => m.userId),
          ['user0', 'user1', 'user2', 'user3']);
      expect(feed.state.hasMore, isTrue);

      await feed.loadMore();
      expect(feed.state.matches, hasLength(5));
      expect(feed.state.hasMore, isFalse);
    });

    test('a full last page leaves one more empty fetch', () async {
      final feed =
          _feed(InMemoryTradeMatchSource(rows: _receivingRows(2)), pageSize: 2);
      await feed.load();
      expect(feed.state.hasMore, isTrue);
      await feed.loadMore();
      expect(feed.state.matches, hasLength(2));
      expect(feed.state.hasMore, isFalse);
    });

    test('loadMore does nothing when there is no more', () async {
      final source = InMemoryTradeMatchSource(rows: _receivingRows(1));
      final feed = _feed(source, pageSize: 2);
      await feed.load();
      expect(feed.state.hasMore, isFalse);

      source.error = Exception('should not be fetched');
      await feed.loadMore();
      expect(feed.state.matches, hasLength(1));
      expect(feed.state.error, isNull);
    });

    test('loadMore while a page is loading does not fetch it twice', () async {
      final feed =
          _feed(InMemoryTradeMatchSource(rows: _receivingRows(5)), pageSize: 2);
      await feed.load();
      await Future.wait([feed.loadMore(), feed.loadMore()]);
      expect(feed.state.matches.map((m) => m.userId),
          ['user0', 'user1', 'user2', 'user3']);
    });
  });

  group('setFilter', () {
    final mixed = [
      _row(userId: 'eng1', send: 'A1-002', sendLanguage: 'ENG', receive: 'A1-001'),
      _row(userId: 'jpn1', send: 'A1-002', sendLanguage: 'JPN', receive: 'A1-001'),
      _row(userId: 'eng2', send: 'A1-003', sendLanguage: 'ENG', receive: 'A1-001'),
      _row(userId: 'jpn2', send: 'A1-003', sendLanguage: 'JPN', receive: 'A1-001'),
      _row(userId: 'jpn3', send: 'A1-004', sendLanguage: 'JPN', receive: 'A1-001'),
    ];

    test('restarts paging from the first page with the new filter', () async {
      final feed = _feed(InMemoryTradeMatchSource(rows: mixed), pageSize: 2);
      await feed.load();
      await feed.loadMore();
      expect(feed.state.matches, hasLength(4));

      await feed.setFilter(TradeMatchFilter(languages: {'JPN'}));
      expect(feed.filter.languages, {'JPN'});
      expect(feed.state.matches.map((m) => m.userId), ['jpn1', 'jpn2']);
      expect(feed.state.hasMore, isTrue);

      await feed.loadMore();
      expect(feed.state.matches.map((m) => m.userId),
          ['jpn1', 'jpn2', 'jpn3']);
      expect(feed.state.hasMore, isFalse);
    });

    test('drops a response that was in flight when the filter changed',
        () async {
      final source = InMemoryTradeMatchSource(rows: mixed);
      final feed = _feed(source, pageSize: 10);
      final slow = Completer<void>();
      source.gate = () => slow.future;
      final stale = feed.load();

      source.gate = null;
      await feed.setFilter(TradeMatchFilter(languages: {'ENG'}));
      slow.complete();
      await stale;

      expect(feed.state.matches.map((m) => m.userId), ['eng1', 'eng2']);
      expect(feed.state.isLoading, isFalse);
    });

    test('drops a next page that was in flight when the filter changed',
        () async {
      final source = InMemoryTradeMatchSource(rows: mixed);
      final feed = _feed(source, pageSize: 2);
      await feed.load();
      final slow = Completer<void>();
      source.gate = () => slow.future;
      final stale = feed.loadMore();

      source.gate = null;
      await feed.setFilter(TradeMatchFilter(languages: {'JPN'}));
      slow.complete();
      await stale;

      expect(feed.state.matches.map((m) => m.userId), ['jpn1', 'jpn2']);
      expect(feed.state.isLoadingMore, isFalse);
      await feed.loadMore();
      expect(feed.state.matches.map((m) => m.userId),
          ['jpn1', 'jpn2', 'jpn3']);
    });
  });

  group('card catalog', () {
    test('waits for the catalog to load before joining matches', () async {
      final catalogLoaded = Completer<Map<String, PocketCard>>();
      final feed = _feed(
        InMemoryTradeMatchSource(rows: _receivingRows(1)),
        catalog: () => catalogLoaded.future,
      );
      final loading = feed.load();
      await pumpEventQueue();
      expect(feed.state.isLoading, isTrue);

      catalogLoaded.complete(_catalog);
      await loading;
      expect(feed.state.matches, hasLength(1));
    });

    test('drops matches whose card is not in the catalog', () async {
      final feed = _feed(
        InMemoryTradeMatchSource(rows: [
          _row(userId: 'known', send: 'A1-002', receive: _viewed.id),
          _row(userId: 'unknown', send: 'B9-999', receive: _viewed.id),
        ]),
        pageSize: 2,
      );
      await feed.load();
      expect(feed.state.matches.map((m) => m.userId), ['known']);
      // The source had a full page, so there may be more.
      expect(feed.state.hasMore, isTrue);
    });
  });

  group('pending proposals', () {
    final rows = [
      _row(userId: 'bob', send: 'A1-002', receive: _viewed.id),
      _row(userId: 'bob', send: 'A1-003', receive: _viewed.id),
      _row(userId: 'eve', send: 'A1-002', receive: _viewed.id),
    ];
    const toBobFor2 = (
      otherUserId: 'bob',
      sendCardId: 'A1-002',
      receiveCardId: 'A1-001',
    );

    Map<String, bool> flags(TradeMatchFeed feed) => {
          for (final m in feed.state.matches)
            '${m.userId}:${m.send.card.id}': m.hasPendingProposal,
        };

    test('flags the matches the user already proposed', () async {
      final feed = _feed(
          InMemoryTradeMatchSource(rows: rows, proposals: {toBobFor2}));
      await feed.load();
      expect(flags(feed),
          {'bob:A1-002': true, 'bob:A1-003': false, 'eve:A1-002': false});
    });

    test('flags matches on later pages too', () async {
      final feed = _feed(
          InMemoryTradeMatchSource(rows: rows.reversed.toList(),
              proposals: {toBobFor2}),
          pageSize: 2);
      await feed.load();
      await feed.loadMore();
      expect(flags(feed)['bob:A1-002'], isTrue);
    });

    test('refreshProposals picks up a proposal sent since loading', () async {
      final source = InMemoryTradeMatchSource(rows: rows);
      final feed = _feed(source);
      await feed.load();
      expect(flags(feed)['bob:A1-002'], isFalse);

      source.proposals = {toBobFor2};
      await feed.refreshProposals();
      expect(flags(feed),
          {'bob:A1-002': true, 'bob:A1-003': false, 'eve:A1-002': false});

      source.proposals = {};
      await feed.refreshProposals();
      expect(flags(feed)['bob:A1-002'], isFalse);
    });
  });

  group('errors', () {
    test('a failed first page sets the error and stops loading', () async {
      final source = InMemoryTradeMatchSource(rows: _receivingRows(1))
        ..error = Exception('offline');
      final feed = _feed(source);
      await feed.load();
      expect(feed.state.error, isNotNull);
      expect(feed.state.isLoading, isFalse);
      expect(feed.state.matches, isEmpty);

      source.error = null;
      await feed.load();
      expect(feed.state.error, isNull);
      expect(feed.state.matches, hasLength(1));
    });

    test('a failed next page keeps the loaded pages, and retrying continues',
        () async {
      final source = InMemoryTradeMatchSource(rows: _receivingRows(3));
      final feed = _feed(source, pageSize: 2);
      await feed.load();

      source.error = Exception('offline');
      await feed.loadMore();
      expect(feed.state.error, isNotNull);
      expect(feed.state.isLoadingMore, isFalse);
      expect(feed.state.matches.map((m) => m.userId), ['user0', 'user1']);

      source.error = null;
      await feed.loadMore();
      expect(feed.state.error, isNull);
      expect(feed.state.matches.map((m) => m.userId),
          ['user0', 'user1', 'user2']);
    });
  });
}
