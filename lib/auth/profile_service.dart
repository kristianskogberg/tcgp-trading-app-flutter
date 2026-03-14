import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  Map<String, dynamic>? _cachedProfile;
  static const _cacheKey = 'cached_profile_v1';
  DateTime? _lastActiveUpdate;

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
      } catch (_) {}
    }
  }

  Future<Map<String, dynamic>?> getProfile({bool forceRefresh = false}) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    await _loadCache();

    if (!forceRefresh && _cachedProfile != null) {
      if (_cachedProfile?['user_id'] == user.id) return _cachedProfile;
    }

    final data = await _client
        .from('profiles')
        .select('user_id, player_name, friend_id, icon')
        .eq('user_id', user.id)
        .maybeSingle();

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

    // Pre-populate cache synchronously so ProfileGate never races the DB write.
    _cachedProfile = payload;

    final saved = await _client
        .from('profiles')
        .upsert(payload, onConflict: 'user_id')
        .select()
        .single();

    _cachedProfile = saved;
    await _persistCache();
  }

  Future<void> updateLastActive() async {
    if (_lastActiveUpdate != null &&
        DateTime.now().difference(_lastActiveUpdate!) <
            const Duration(minutes: 5)) {
      return;
    }
    await _client.rpc('update_last_active');
    _lastActiveUpdate = DateTime.now();
  }

  Future<void> deleteProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client.from('profiles').delete().eq('user_id', user.id);
  }

  Future<void> clearProfileCache() async {
    _cachedProfile = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }
}
