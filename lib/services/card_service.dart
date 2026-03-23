import 'dart:convert';
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
          await _persistCache(prefs);
          return _cards!;
        }
      }

      // Load from disk cache if in-memory is empty
      if (_cards == null || _cards!.isEmpty) {
        _loadFromDiskCache(prefs);
      }

      // Try incremental sync with disk cache
      final diskLastSync = prefs.getString(_lastSyncKey);
      if (diskLastSync != null && _cards != null && _cards!.isNotEmpty) {
        final updated = await _fetchUpdatedCards(diskLastSync);
        if (updated != null) {
          _mergeUpdatedCards(updated);
          await _persistCache(prefs);
          return _cards!;
        }
      }

      // Full fetch — parallel batches
      final allData = await _fetchAllCardsParallel();
      _cards = allData.map((e) => PocketCard.fromJson(e)).toList();
      _cardMap = null;
      await _persistCache(prefs, rawData: allData);
      return _cards!;
    } catch (_) {
      // Fall through to cache
    }

    // Fallback: load from disk cache
    if (_cards == null || _cards!.isEmpty) {
      _loadFromDiskCache(prefs);
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
    for (int offset = _batchSize; offset < _batchSize * 5; offset += _batchSize) {
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
    } catch (_) {
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

    final updatedCards =
        updated.map((e) => PocketCard.fromJson(e as Map<String, dynamic>)).toList();
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
  Future<void> _persistCache(SharedPreferences prefs, {List<dynamic>? rawData}) async {
    final data = rawData ?? _cards!.map((c) => c.toJson()).toList();
    await prefs.setString(_cacheKey, json.encode(data));
    _cachedAt ??= DateTime.now();
    await prefs.setInt(_cacheTimestampKey, _cachedAt!.millisecondsSinceEpoch);
    await prefs.setString(_lastSyncKey, DateTime.now().toUtc().toIso8601String());
  }

  /// Load cards from SharedPreferences disk cache into memory.
  void _loadFromDiskCache(SharedPreferences prefs) {
    final cached = prefs.getString(_cacheKey);
    if (cached != null) {
      final List<dynamic> jsonList = json.decode(cached);
      _cards = jsonList
          .map((e) => PocketCard.fromJson(e as Map<String, dynamic>))
          .toList();
      _cardMap = null;
      final timestamp = prefs.getInt(_cacheTimestampKey);
      if (timestamp != null) {
        _cachedAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
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

  /// Precache the first [count] card images to disk for instant loading.
  Future<void> precacheCardImages({int count = 30}) async {
    final cards = _cards;
    if (cards == null || cards.isEmpty) return;
    final urls = cards.take(count).map((c) => c.imageUrl);
    for (final url in urls) {
      try {
        await CardImageCacheManager.instance.getSingleFile(url);
      } catch (_) {
        // Silently ignore — precaching is best-effort
      }
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
