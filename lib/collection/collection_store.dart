import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tcgp_trading_app/collection/collection.dart';
import 'package:tcgp_trading_app/collection/collection_rows.dart';
import 'package:tcgp_trading_app/models/trade_match.dart';
import 'package:tcgp_trading_app/utils/async_utils.dart';

/// Holds the signed-in user's [Collection], keeps it cached on the device and
/// is the only place that reads or writes collection rows in Supabase.
class CollectionStore extends ChangeNotifier {
  static final CollectionStore _instance = CollectionStore._internal();
  factory CollectionStore() => _instance;
  CollectionStore._internal();

  final SupabaseClient _client = Supabase.instance.client;

  Collection _collection = Collection();

  /// The signed-in user's collection as last loaded or saved.
  Collection get collection => _collection;

  bool _loaded = false;
  String? _loadedUserId;
  static const _cacheKey = 'cached_collection_v1';
  static const _cacheUserKey = 'cached_collection_user_id';
  static const _legacyCacheKeys = [
    'cached_user_cards_v2',
    'cached_user_cards_v3',
    'cached_user_cards_user_id',
    'cached_trade_conditions_v2',
  ];

  Future<void> _persistCache() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = _client.auth.currentUser?.id;
    await prefs.setString(_cacheKey, jsonEncode(collectionToCache(_collection)));
    if (userId != null) {
      await prefs.setString(_cacheUserKey, userId);
    }
  }

  Future<void> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedUserId = prefs.getString(_cacheUserKey);
    final currentUserId = _client.auth.currentUser?.id;

    if (_loaded && _loadedUserId == currentUserId) return;

    _collection = Collection();
    for (final key in _legacyCacheKeys) {
      await prefs.remove(key);
    }

    // Discard cache if it belongs to a different user
    if (cachedUserId != null && cachedUserId != currentUserId) {
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheUserKey);
      _loaded = true;
      _loadedUserId = currentUserId;
      return;
    }

    final raw = prefs.getString(_cacheKey);
    if (raw != null) {
      try {
        _collection =
            collectionFromCache(jsonDecode(raw) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('Failed to decode cached collection: $e');
      }
    }
    _loaded = true;
    _loadedUserId = currentUserId;
  }

  /// Loads the signed-in user's collection, from the device cache when it
  /// has one unless [forceRefresh] is set.
  Future<void> load({bool forceRefresh = false}) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _loadCache();
    if (!forceRefresh &&
        (_collection.wishlist.isNotEmpty || _collection.listings.isNotEmpty)) {
      notifyListeners();
      return;
    }

    final cardRows = await withTimeout(_client
        .from('user_cards')
        .select('card_id, type, language')
        .eq('user_id', user.id));

    var conditionRows = <Map<String, dynamic>>[];
    try {
      conditionRows = await withTimeout(_client
          .from('trade_conditions')
          .select('listed_card_id, wanted_card_id, wanted_language')
          .eq('user_id', user.id));
    } catch (e) {
      // Table may not exist yet - conditions will work from cache only
      debugPrint('Failed to load trade conditions: $e');
    }

    _collection =
        collectionFromRows(cardRows: cardRows, conditionRows: conditionRows);
    await _persistCache();
    notifyListeners();
  }

  /// Fetches another user's collection. Trade conditions are not included.
  Future<Collection> fetchCollectionOf(String userId) async {
    final cardRows = await withTimeout(_client
        .from('user_cards')
        .select('card_id, type, language')
        .eq('user_id', userId));
    return collectionFromRows(cardRows: cardRows, conditionRows: const []);
  }

  /// Saves the [changes] of a Collection draft in one atomic call and, on
  /// success, applies them to [collection] and the device cache without
  /// reloading. Throws if the save fails; nothing is changed then.
  Future<void> commit(Map<String, CardState> changes) async {
    if (changes.isEmpty) return;
    if (_client.auth.currentUser == null) {
      throw Exception('No authenticated user');
    }

    // See supabase/save_collection_changes.sql.
    await withTimeout(_client.rpc('save_collection_changes', params: {
      'p_changes': changesToSavePayload(changes),
    }));

    _collection = _collection.withChanges(changes);
    await _persistCache();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Trade matches
  // ---------------------------------------------------------------------------

  /// Find users who list [cardId], then return their wishlist cards with profile info.
  Future<List<TradeMatch>> getTradeMatchesForWanted(
    String cardId,
    List<String> languages, {
    bool fullartOnly = false,
    required int limit,
    required int offset,
  }) async {
    if (_client.auth.currentUser == null) return [];

    final rows =
        await withTimeout(_client.rpc('get_trade_matches_for_wanted', params: {
      'p_card_id': cardId,
      'p_languages': languages,
      'p_fullart_only': fullartOnly,
      'p_limit': limit,
      'p_offset': offset,
    }));

    return (rows as List)
        .map((r) => TradeMatch.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Find users who want [cardId], then return their listings with profile info.
  Future<List<TradeMatch>> getTradeMatchesForListing(
    String cardId,
    List<String> languages, {
    bool fullartOnly = false,
    required int limit,
    required int offset,
  }) async {
    if (_client.auth.currentUser == null) return [];

    final rows =
        await withTimeout(_client.rpc('get_trade_matches_for_listing', params: {
      'p_card_id': cardId,
      'p_languages': languages,
      'p_fullart_only': fullartOnly,
      'p_limit': limit,
      'p_offset': offset,
    }));

    return (rows as List)
        .map((r) => TradeMatch.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Returns a set of "userId:offerCardId:receiveCardId" keys for all
  /// pending trade proposals sent by the current user.
  Future<Set<String>> getMyPendingProposals() async {
    final rows = await withTimeout(_client.rpc('get_my_pending_proposals'));
    return (rows as List).map((r) {
      final m = r as Map<String, dynamic>;
      return '${m['other_user_id']}:${m['offer_card_id']}:${m['receive_card_id']}';
    }).toSet();
  }

  // ---------------------------------------------------------------------------
  // Account
  // ---------------------------------------------------------------------------

  Future<void> deleteAll() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await withTimeout(
        _client.from('user_cards').delete().eq('user_id', user.id));
    _collection = Collection();
    await _persistCache();
    notifyListeners();
  }

  Future<void> clearCache() async {
    _collection = Collection();
    _loaded = false;
    _loadedUserId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheUserKey);
    for (final key in _legacyCacheKeys) {
      await prefs.remove(key);
    }
    notifyListeners();
  }
}
