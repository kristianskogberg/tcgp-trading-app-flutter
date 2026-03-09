import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tcgp_trading_app/models/trade_match.dart';

class UserCardEntry {
  final String cardId;
  final String language;

  const UserCardEntry({required this.cardId, required this.language});

  String get key => '$cardId:$language';

  Map<String, dynamic> toJson() => {'cardId': cardId, 'language': language};

  factory UserCardEntry.fromJson(Map<String, dynamic> json) => UserCardEntry(
        cardId: json['cardId'] as String,
        language: json['language'] as String? ?? 'ANY',
      );

  /// Whether this entry represents "any language".
  bool get isAny => language == 'ANY';
}

class UserCardService {
  static final UserCardService _instance = UserCardService._internal();
  factory UserCardService() => _instance;
  UserCardService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  /// Maps "cardId:language" -> UserCardEntry
  Map<String, UserCardEntry> _wishlist = {};
  Map<String, UserCardEntry> _owned = {};
  bool _loaded = false;
  String? _cachedUserId;
  static const _cacheKey = 'cached_user_cards_v2';
  static const _cacheUserKey = 'cached_user_cards_user_id';

  Future<void> _persistCache() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = _client.auth.currentUser?.id;
    await prefs.setString(
      _cacheKey,
      jsonEncode({
        'wishlist': _wishlist.values.map((e) => e.toJson()).toList(),
        'owned': _owned.values.map((e) => e.toJson()).toList(),
      }),
    );
    if (userId != null) {
      await prefs.setString(_cacheUserKey, userId);
    }
  }

  Future<void> _loadCache() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final cachedUserId = prefs.getString(_cacheUserKey);
    final currentUserId = _client.auth.currentUser?.id;

    // Discard cache if it belongs to a different user
    if (cachedUserId != null && cachedUserId != currentUserId) {
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheUserKey);
      _loaded = true;
      return;
    }

    final raw = prefs.getString(_cacheKey);
    if (raw != null) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _wishlist = _parseEntries(data['wishlist'] as List);
        _owned = _parseEntries(data['owned'] as List);
        _cachedUserId = cachedUserId;
      } catch (_) {}
    }
    _loaded = true;
  }

  Map<String, UserCardEntry> _parseEntries(List list) {
    final map = <String, UserCardEntry>{};
    for (final item in list) {
      final entry = UserCardEntry.fromJson(item as Map<String, dynamic>);
      map[entry.key] = entry;
    }
    return map;
  }

  Future<void> loadMyCards({bool forceRefresh = false}) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _loadCache();
    if (!forceRefresh && (_wishlist.isNotEmpty || _owned.isNotEmpty)) return;

    final rows = await _client
        .from('user_cards')
        .select('card_id, type, language')
        .eq('user_id', user.id);

    _wishlist = {};
    _owned = {};
    for (final row in rows) {
      final entry = UserCardEntry(
        cardId: row['card_id'] as String,
        language: row['language'] as String,
      );
      if (row['type'] == 'wishlist') {
        _wishlist[entry.key] = entry;
      } else if (row['type'] == 'owned') {
        _owned[entry.key] = entry;
      }
    }
    await _persistCache();
  }

  bool isWishlisted(String cardId) =>
      _wishlist.values.any((e) => e.cardId == cardId);

  bool isOwned(String cardId) => _owned.values.any((e) => e.cardId == cardId);

  /// Returns the set of languages for which the user has this card in the given type.
  Set<String> getLanguages(String cardId, String type) {
    final map = type == 'wishlist' ? _wishlist : _owned;
    return map.values
        .where((e) => e.cardId == cardId)
        .map((e) => e.language)
        .toSet();
  }

  Future<void> addCard(String cardId, String type, String language) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    final entry = UserCardEntry(cardId: cardId, language: language);
    final map = type == 'wishlist' ? _wishlist : _owned;

    if (map.containsKey(entry.key)) return;

    await _client.from('user_cards').insert({
      'user_id': user.id,
      'card_id': cardId,
      'type': type,
      'language': language,
    });
    map[entry.key] = entry;
    await _persistCache();
  }

  Future<void> removeCard(String cardId, String type, String language) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    final key = '$cardId:$language';
    final map = type == 'wishlist' ? _wishlist : _owned;

    await _client
        .from('user_cards')
        .delete()
        .eq('user_id', user.id)
        .eq('card_id', cardId)
        .eq('type', type)
        .eq('language', language);
    map.remove(key);
    await _persistCache();
  }

  /// Find users who own [cardId], then return their wishlist cards with profile info.
  Future<List<TradeMatch>> getTradeMatchesForWanted(
      String cardId, List<String> languages) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final rows = await _client.rpc('get_trade_matches_for_wanted', params: {
      'p_card_id': cardId,
      'p_user_id': user.id,
      'p_languages': languages,
    });

    return (rows as List)
        .map((r) => TradeMatch.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Find users who want [cardId], then return their owned cards with profile info.
  Future<List<TradeMatch>> getTradeMatchesForOwned(
      String cardId, List<String> languages) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final rows = await _client.rpc('get_trade_matches_for_owned', params: {
      'p_card_id': cardId,
      'p_user_id': user.id,
      'p_languages': languages,
    });

    return (rows as List)
        .map((r) => TradeMatch.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> clearCache() async {
    _wishlist = {};
    _owned = {};
    _loaded = false;
    _cachedUserId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheUserKey);
  }
}
