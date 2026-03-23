import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/services/card_image_cache_manager.dart';

class CardService {
  static const _cacheKey = 'cached_cards_json';
  static const _staleEtagKey = 'cached_cards_etag';
  static const _cacheTimestampKey = 'cached_cards_timestamp';
  static const _cacheTtl = Duration(hours: 6);

  static final CardService _instance = CardService._();
  factory CardService() => _instance;
  CardService._();

  final SupabaseClient _client = Supabase.instance.client;

  List<PocketCard>? _cards;
  Map<String, PocketCard>? _cardMap;
  DateTime? _cachedAt;

  /// Load cards from Supabase. Falls back to cache if offline.
  ///
  /// Uses a 6-hour TTL: if the cached data is older than that, a fresh
  /// fetch from Supabase is attempted. On network failure the stale cache
  /// is still returned so the app remains usable offline.
  Future<List<PocketCard>> getAllCards({bool forceRefresh = false}) async {
    final isExpired =
        _cachedAt != null && DateTime.now().difference(_cachedAt!) > _cacheTtl;
    if (_cards != null && !forceRefresh && !isExpired) return _cards!;

    final prefs = await SharedPreferences.getInstance();

    try {
      final List<dynamic> allData = [];
      const batchSize = 1000;
      int offset = 0;
      while (true) {
        final batch = await _client
            .from('cards')
            .select()
            .range(offset, offset + batchSize - 1)
            .timeout(const Duration(seconds: 10));
        allData.addAll(batch);
        if (batch.length < batchSize) break;
        offset += batchSize;
      }

      final data = allData;
      final List<dynamic> jsonList = data;
      _cards = jsonList.map((e) => PocketCard.fromJson(e)).toList();

      // Cache for offline fallback
      await prefs.setString(_cacheKey, json.encode(data));
      _cachedAt = DateTime.now();
      await prefs.setInt(
          _cacheTimestampKey, _cachedAt!.millisecondsSinceEpoch);

      // Clean up stale ETag key from previous GitHub-based implementation
      if (prefs.containsKey(_staleEtagKey)) {
        await prefs.remove(_staleEtagKey);
      }

      return _cards!;
    } catch (_) {
      // Fall through to cache
    }

    // Fallback: load from cache
    final cached = prefs.getString(_cacheKey);
    if (cached != null) {
      final List<dynamic> jsonList = json.decode(cached);
      _cards = jsonList.map((e) => PocketCard.fromJson(e)).toList();
      final timestamp = prefs.getInt(_cacheTimestampKey);
      if (timestamp != null) {
        _cachedAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      return _cards!;
    }

    return [];
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
  }
}
