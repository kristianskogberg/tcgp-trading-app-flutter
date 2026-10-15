import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tcgp_trading_app/auth/preferred_language.dart';
import 'package:tcgp_trading_app/utils/async_utils.dart';

class ProfileService {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  Map<String, dynamic>? _cachedProfile;
  static const _cacheKey = 'cached_profile_v1';
  DateTime? _lastActiveUpdate;

  /// Counts profile writes, so a fetch that a write overtook doesn't cache
  /// the row as it was before the write.
  int _writes = 0;

  Future<void> _persistCache() async {
    if (_cachedProfile == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(_cachedProfile));
  }

  Future<void> _loadCache() async {
    if (_cachedProfile != null) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw != null) {
      try {
        _cachedProfile = jsonDecode(raw) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('Failed to decode cached profile: $e');
      }
    }
  }

  Future<Map<String, dynamic>?> getProfile({bool forceRefresh = false}) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    await _loadCache();

    if (!forceRefresh && _cachedProfile != null) {
      if (_cachedProfile?['user_id'] == user.id) return _cachedProfile;
    }

    final writesBefore = _writes;
    final data = await withTimeout(_client
        .from('profiles')
        .select('user_id, player_name, friend_id, icon, preferred_language')
        .eq('user_id', user.id)
        .maybeSingle());
    if (_writes != writesBefore) return _cachedProfile;

    _cachedProfile = data;
    await _persistCache();
    return _cachedProfile;
  }

  Future<void> saveProfile({
    required String playerName,
    required String friendId,
    String? icon,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    final payload = {
      'user_id': user.id,
      'player_name': playerName,
      'friend_id': friendId,
      'icon': icon,
    };

    // Pre-populate cache synchronously so reads don't race the DB write.
    _writes++;
    _cachedProfile = {...?_cachedProfile, ...payload};

    final saved = await withTimeout(_client
        .from('profiles')
        .upsert(payload, onConflict: 'user_id')
        .select()
        .single());

    _cachedProfile = saved;
    await _persistCache();
  }

  /// The signed-in user's Preferred language, or null if it's unset. A
  /// profile that can't be fetched falls back to the cached one. A profile
  /// cached before the language existed counts as unset.
  Future<String?> getPreferredLanguage({bool forceRefresh = false}) async {
    try {
      return preferredLanguageOf(await getProfile(forceRefresh: forceRefresh));
    } catch (e) {
      debugPrint('Failed to load preferred language: $e');
      final userId = _client.auth.currentUser?.id;
      final cached = _cachedProfile;
      return cached != null && cached['user_id'] == userId
          ? preferredLanguageOf(cached)
          : null;
    }
  }

  /// Stores [language], a specific card language, as the signed-in user's
  /// Preferred language. Throws if it isn't saved.
  Future<void> savePreferredLanguage(String language) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    _writes++;
    final saved = await withTimeout(_client
        .from('profiles')
        .update({'preferred_language': language})
        .eq('user_id', user.id)
        .select()
        .single());

    _cachedProfile = saved;
    await _persistCache();
  }

  Future<void> updateLastActive() async {
    if (_lastActiveUpdate != null &&
        DateTime.now().difference(_lastActiveUpdate!) <
            const Duration(minutes: 5)) {
      return;
    }
    await withTimeout(_client.rpc('update_last_active'));
    _lastActiveUpdate = DateTime.now();
  }

  Future<void> deleteProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client.from('profiles').delete().eq('user_id', user.id);
  }

  Future<Map<String, dynamic>?> getOtherUserProfile(String userId) async {
    final data = await withTimeout(_client
        .from('profiles')
        .select('user_id, player_name, icon')
        .eq('user_id', userId)
        .maybeSingle());
    return data;
  }

  Future<void> clearProfileCache() async {
    _cachedProfile = null;
    _lastActiveUpdate = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }
}
