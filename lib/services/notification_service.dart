import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tcgp_trading_app/main.dart';
import 'package:tcgp_trading_app/screens/chat_screen.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _messaging = FirebaseMessaging.instance;
  final _client = Supabase.instance.client;

  /// Track which conversation is currently open to prevent duplicate pushes
  String? activeConversationId;

  bool _initialized = false;
  StreamSubscription<String>? _tokenRefreshSub;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final settings = await _messaging.requestPermission();
    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint('Notification permission denied');
      return;
    }

    final token = await _messaging.getToken();
    if (token != null) {
      await _saveToken(token);
    }

    _tokenRefreshSub = _messaging.onTokenRefresh.listen(
      _saveToken,
      onError: (e) => debugPrint('Token refresh error: $e'),
    );

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationTap);

    // Handle notification tap when app was terminated
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      // Wait for the widget tree to finish building before navigating
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onNotificationTap(initialMessage);
      });
    }
  }

  void _onNotificationTap(RemoteMessage message) {
    final conversationId = message.data['conversation_id'] as String?;
    final senderId = message.data['sender_id'] as String?;
    if (conversationId == null || senderId == null) return;

    // Don't push duplicate screen for the same conversation
    if (activeConversationId == conversationId) return;

    _openConversation(conversationId, senderId);
  }

  Future<void> _openConversation(String conversationId, String senderId) async {
    try {
      // Fetch sender's profile for display
      final profile = await _client
          .from('profiles')
          .select('player_name, icon')
          .eq('user_id', senderId)
          .single();

      final playerName = profile['player_name'] as String? ?? 'Unknown';
      final icon = profile['icon'] as String?;

      final nav = navigatorKey.currentState;
      if (nav == null) return;

      nav.push(
        MaterialPageRoute(
          builder: (_) => ChatScreen.fromConversation(
            conversationId: conversationId,
            otherUserId: senderId,
            otherPlayerName: playerName,
            otherIcon: icon,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Failed to open conversation from notification: $e');
    }
  }

  Future<void> _saveToken(String token) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _client.from('device_tokens').upsert(
        {
          'user_id': userId,
          'token': token,
          'platform': 'android',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id, token',
      );
    } catch (e) {
      debugPrint('Failed to save FCM token: $e');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground message: ${message.notification?.title}');
    // Foreground messages are handled by the in-app badge system,
    // so we don't show a duplicate notification here.
  }

  Future<void> removeToken() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final token = await _messaging.getToken();
      if (token != null) {
        // Remove from our database
        await _client
            .from('device_tokens')
            .delete()
            .eq('user_id', userId)
            .eq('token', token);
      }
      // Delete the FCM token so Firebase stops delivering to this device
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('Failed to remove FCM token: $e');
    }

    // Cancel subscription and allow re-initialization on next login
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    _initialized = false;
  }
}
