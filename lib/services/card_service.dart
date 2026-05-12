import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/services/card_image_cache_manager.dart';

class CardService {
  static const _cacheKey = 'cached_cards_json';
  static const _cacheTimestampKey = 'cached_cards_timestamp';
  static const _lastSyncKey = 'cached_cards_last_sync';
  static const _cacheTtl = Duration(hours: 6);
  static const _batchSize = 1000;

  static final CardService _instance = CardService._();
  factory CardService() => _instance;
  CardService._();

  final SupabaseClient _client = Supabase.instance.client;

  List<PocketCard>? _cards;
  Map<String, PocketCard>? _cardMap;
  DateTime? _cachedAt;

  /// Load cards from Supabase. Falls back to cache if offline.
  ///
  /// Uses a 6-hour TTL. On refresh, performs an incremental sync
  /// (only fetches cards updated since the last sync) when a local
  /// cache exists, or a full parallel fetch for cold starts.
  Future<List<PocketCard>> getAllCards({bool forceRefresh = false}) async {
    final isExpired =
        _cachedAt != null && DateTime.now().difference(_cachedAt!) > _cacheTtl;
    if (_cards != null && !forceRefresh && !isExpired) return _cards!;

    final prefs = await SharedPreferences.getInstance();

    try {
      // Try incremental sync first if we have a cache
      final lastSync = prefs.getString(_lastSyncKey);
      if (lastSync != null && _cards != null && _cards!.isNotEmpty) {
        final updated = await _fetchUpdatedCards(lastSync);
        if (updated != null) {
          _mergeUpdatedCards(updated);
          await _persistCache(
            prefs,
            syncCursor: _nextSyncCursor(lastSync, updated),
          );
          return _cards!;
        }
      }

      // Load from disk cache if in-memory is empty
      if (_cards == null || _cards!.isEmpty) {
        await _loadFromDiskCache(prefs);
      }

      // Try incremental sync with disk cache
      final diskLastSync = prefs.getString(_lastSyncKey);
      if (diskLastSync != null && _cards != null && _cards!.isNotEmpty) {
        final updated = await _fetchUpdatedCards(diskLastSync);
        if (updated != null) {
          _mergeUpdatedCards(updated);
          await _persistCache(
            prefs,
            syncCursor: _nextSyncCursor(diskLastSync, updated),
          );
          return _cards!;
        }
      }

      // Full fetch — parallel batches
      final allData = await _fetchAllCardsParallel();
      _cards = allData.map((e) => PocketCard.fromJson(e)).toList();
      _cardMap = null;
      await _persistCache(
        prefs,
        rawData: allData,
        syncCursor: _maxUpdatedAt(allData),
      );
      return _cards!;
    } catch (e) {
      // Fall through to cache
      debugPrint('Card sync failed, falling back to cache: $e');
    }

    // Fallback: load from disk cache
    if (_cards == null || _cards!.isEmpty) {
      await _loadFromDiskCache(prefs);
    }
    return _cards ?? [];
  }

  /// Fetch all cards in parallel batches.
  Future<List<dynamic>> _fetchAllCardsParallel() async {
    // First batch to determine total count
    final firstBatch = await _client
        .from('cards')
        .select()
        .order('id')
        .range(0, _batchSize - 1)
        .timeout(const Duration(seconds: 10));

    if (firstBatch.length < _batchSize) return firstBatch;

    // Fetch remaining batches in parallel
    // Estimate ~3 batches for ~3000 cards; fetch up to 5 to be safe
    final futures = <Future<List<dynamic>>>[];
    for (int offset = _batchSize;
        offset < _batchSize * 5;
        offset += _batchSize) {
      futures.add(
        _client
            .from('cards')
            .select()
            .order('id')
            .range(offset, offset + _batchSize - 1)
            .timeout(const Duration(seconds: 10)),
      );
    }

    final batches = await Future.wait(futures);
    final allData = <dynamic>[...firstBatch];
    for (final batch in batches) {
      if (batch.isEmpty) break;
      allData.addAll(batch);
      if (batch.length < _batchSize) break;
    }
    return allData;
  }

  /// Fetch only cards updated since [lastSync].
  /// Returns null if the fetch fails (caller falls back to full fetch).
  Future<List<dynamic>?> _fetchUpdatedCards(String lastSync) async {
    try {
      final data = await _client
          .from('cards')
          .select()
          .gt('updated_at', lastSync)
          .timeout(const Duration(seconds: 10));
      return data;
    } catch (e) {
      debugPrint('Incremental card sync failed: $e');
      return null;
    }
  }

  /// Merge updated/new cards into the in-memory list.
  void _mergeUpdatedCards(List<dynamic> updated) {
    if (updated.isEmpty) {
      // No changes — just refresh the timestamp
      _cachedAt = DateTime.now();
      return;
    }

    final updatedCards = updated
        .map((e) => PocketCard.fromJson(e as Map<String, dynamic>))
        .toList();
    final cardMap = <String, PocketCard>{};
    for (final c in _cards!) {
      cardMap[c.id] = c;
    }
    for (final c in updatedCards) {
      cardMap[c.id] = c;
    }
    _cards = cardMap.values.toList();
    _cardMap = null;
    _cachedAt = DateTime.now();
  }

  /// Persist current cards to SharedPreferences.
  Future<void> _persistCache(SharedPreferences prefs,
      {List<dynamic>? rawData, String? syncCursor}) async {
    final data = rawData ?? _cards!.map((c) => c.toJson()).toList();
    await prefs.setString(_cacheKey, json.encode(data));
    _cachedAt = DateTime.now();
    await prefs.setInt(_cacheTimestampKey, _cachedAt!.millisecondsSinceEpoch);
    final nextSyncCursor = syncCursor ?? prefs.getString(_lastSyncKey);
    if (nextSyncCursor != null) {
      await prefs.setString(_lastSyncKey, nextSyncCursor);
    }
  }

  String _nextSyncCursor(String currentCursor, List<dynamic> updatedRows) {
    final maxUpdatedAt = _maxUpdatedAt(updatedRows);
    if (maxUpdatedAt == null) return currentCursor;
    final current = DateTime.tryParse(currentCursor);
    final next = DateTime.tryParse(maxUpdatedAt);
    if (current == null || next == null || next.isAfter(current)) {
      return maxUpdatedAt;
    }
    return currentCursor;
  }

  String? _maxUpdatedAt(Iterable<dynamic> rows) {
    DateTime? max;
    for (final row in rows) {
      if (row is! Map<String, dynamic>) continue;
      final raw = row['updated_at'] as String?;
      if (raw == null) continue;
      final parsed = DateTime.tryParse(raw);
      if (parsed == null) continue;
      if (max == null || parsed.isAfter(max)) {
        max = parsed;
      }
    }
    return max?.toUtc().toIso8601String();
  }

  /// Load cards from SharedPreferences disk cache into memory.
  Future<void> _loadFromDiskCache(SharedPreferences prefs) async {
    final cached = prefs.getString(_cacheKey);
    if (cached != null) {
      try {
        final List<dynamic> jsonList = json.decode(cached);
        _cards = jsonList
            .map((e) => PocketCard.fromJson(e as Map<String, dynamic>))
            .toList();
        _cardMap = null;
        final timestamp = prefs.getInt(_cacheTimestampKey);
        if (timestamp != null) {
          _cachedAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
        }
      } catch (e) {
        debugPrint('Failed to decode cached cards, clearing cache: $e');
        _cards = null;
        _cardMap = null;
        _cachedAt = null;
        await prefs.remove(_cacheKey);
        await prefs.remove(_cacheTimestampKey);
        await prefs.remove(_lastSyncKey);
      }
    }
  }

  /// Get cards filtered by set.
  Future<List<PocketCard>> getCardsBySet(String set) async {
    final all = await getAllCards();
    return all.where((c) => c.set == set).toList();
  }

  /// Get a single card by id.
  Future<PocketCard?> getCard(String id) async {
    final all = await getAllCards();
    try {
      return all.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Map<String, PocketCard> getCardMap() {
    if (_cardMap != null) return _cardMap!;
    if (_cards == null) return {};
    _cardMap = {for (final c in _cards!) c.id: c};
    return _cardMap!;
  }

  /// Precache the first [count] card images to disk for faster initial scrolling.
  Future<void> precacheCardImages({
    List<PocketCard>? cards,
    int count = 48,
  }) async {
    final sourceCards = cards ?? _cards;
    if (sourceCards == null || sourceCards.isEmpty) return;
    final urls = sourceCards
        .take(count)
        .map((c) => c.imageUrl)
        .where((url) => url.isNotEmpty)
        .toList();
    const batchSize = 6;
    for (var start = 0; start < urls.length; start += batchSize) {
      final batch = urls.skip(start).take(batchSize);
      await Future.wait(
        batch.map((url) async {
          try {
            await CardImageCacheManager.instance.getSingleFile(url);
          } catch (e) {
            // Precaching is best-effort; visible widgets will still retry.
            debugPrint('Precache failed for $url: $e');
          }
        }),
      );
    }
  }

  /// Clear all cached card data (in-memory and persisted).
  Future<void> clearCache() async {
    _cards = null;
    _cardMap = null;
    _cachedAt = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheTimestampKey);
    await prefs.remove(_lastSyncKey);
  }
}
