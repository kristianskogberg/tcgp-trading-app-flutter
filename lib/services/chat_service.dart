import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tcgp_trading_app/models/message.dart';
import 'package:safe_text/safe_text.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  Future<String> getOrCreateConversation(String otherUserId) async {
    final result = await _client.rpc(
      'get_or_create_conversation',
      params: {'p_other_user_id': otherUserId},
    );
    return result as String;
  }

  Future<Message> sendTradeMessage(
    String conversationId,
    String offerCardId,
    String offerLanguage,
    String receiveCardId,
    String receiveLanguage,
  ) async {
    return sendMessage(
      conversationId,
      'TRADE:$offerCardId:$offerLanguage:$receiveCardId:$receiveLanguage:pending',
    );
  }

  Future<List<Message>> getMessages(
    String conversationId, {
    int limit = 30,
    DateTime? before,
  }) async {
    var query =
        _client.from('messages').select().eq('conversation_id', conversationId);

    if (before != null) {
      query = query.lt('created_at', before.toIso8601String());
    }

    final rows = await query.order('created_at', ascending: false).limit(limit);
    return (rows as List)
        .map((r) => Message.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<Message> sendMessage(String conversationId, String content) async {
    final userId = _client.auth.currentUser!.id;
    final trimmed = content.trim();
    if (trimmed.isEmpty) throw Exception('Message cannot be empty');
    final isSpecial = trimmed.startsWith('TRADE:') ||
        trimmed.startsWith('FRIENDID:') ||
        trimmed.startsWith('TRADERESULT:');
    if (!isSpecial && trimmed.length > 100) {
      throw Exception('Message too long');
    }
    if (!isSpecial && await SafeTextFilter.containsBadWord(text: trimmed)) {
      throw Exception(
          'Message contains inappropriate language. Please rephrase.');
    }

    final row = await _client
        .from('messages')
        .insert({
          'conversation_id': conversationId,
          'sender_id': userId,
          'content': trimmed,
        })
        .select()
        .single();

    // Update conversation metadata (fire-and-forget)
    final displayText = trimmed.startsWith('TRADE:')
        ? 'Trade proposal'
        : trimmed.startsWith('FRIENDID:')
            ? 'Shared Friend ID'
            : trimmed.startsWith('TRADERESULT:')
                ? (trimmed.contains(':accepted:')
                    ? 'Trade accepted'
                    : 'Trade denied')
                : (trimmed.length > 100
                    ? '${trimmed.substring(0, 100)}...'
                    : trimmed);
    _client
        .from('conversations')
        .update({
          'last_message_at': DateTime.now().toUtc().toIso8601String(),
          'last_message_text': displayText,
        })
        .eq('id', conversationId)
        .then((_) {})
        .catchError((_) {});

    return Message.fromJson(row);
  }

  Future<void> updateTradeStatus(String messageId, String newStatus) async {
    final row = await _client
        .from('messages')
        .select('content')
        .eq('id', messageId)
        .single();

    final content = row['content'] as String;
    final parts = content.split(':');
    // Replace or append status segment (index 5)
    if (parts.length > 5) {
      parts[5] = newStatus;
    } else {
      parts.add(newStatus);
    }

    await _client
        .from('messages')
        .update({'content': parts.join(':')}).eq('id', messageId);
  }

  RealtimeChannel subscribeToMessages(
    String conversationId,
    void Function(Message message) onMessage, {
    void Function(Message message)? onUpdate,
  }) {
    return _client
        .channel('messages:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            final msg = Message.fromJson(payload.newRecord);
            onMessage(msg);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            if (onUpdate != null) {
              final msg = Message.fromJson(payload.newRecord);
              onUpdate(msg);
            }
          },
        )
        .subscribe();
  }

  Future<List<Map<String, dynamic>>> getConversations() async {
    final userId = _client.auth.currentUser!.id;
    final rows = await _client
        .from('conversations')
        .select()
        .or('user_a.eq.$userId,user_b.eq.$userId')
        .not('last_message_text', 'is', null)
        .order('last_message_at', ascending: false);

    // Collect other-user IDs to fetch their profile names
    final otherUserIds = (rows as List).map((r) {
      final row = r as Map<String, dynamic>;
      return row['user_a'] == userId ? row['user_b'] : row['user_a'];
    }).toSet();

    if (otherUserIds.isEmpty) return [];

    final profiles = await _client
        .from('profiles')
        .select('user_id, player_name, icon')
        .inFilter('user_id', otherUserIds.toList());

    final profileMap = <String, Map<String, dynamic>>{};
    for (final p in profiles) {
      profileMap[p['user_id'] as String] = p;
    }

    final result = <Map<String, dynamic>>[];
    for (final r in rows) {
      final isUserA = r['user_a'] == userId;
      final otherUserId = isUserA ? r['user_b'] : r['user_a'];
      final profile = profileMap[otherUserId];
      // Skip conversations where the other user's profile no longer exists
      if (profile == null) continue;
      final unreadCount =
          (isUserA ? r['unread_count_a'] : r['unread_count_b']) as int? ?? 0;
      result.add({
        ...r,
        'other_user_id': otherUserId,
        'other_player_name': profile['player_name'] as String? ?? 'Unknown',
        'other_icon': profile['icon'] as String?,
        'unread_count': unreadCount,
      });
    }
    return result;
  }

  Future<void> markConversationAsRead(String conversationId) async {
    final userId = _client.auth.currentUser!.id;
    final row = await _client
        .from('conversations')
        .select('user_a')
        .eq('id', conversationId)
        .single();

    final isUserA = row['user_a'] == userId;
    await _client.from('conversations').update({
      if (isUserA) 'unread_count_a': 0 else 'unread_count_b': 0,
    }).eq('id', conversationId);
  }

  Future<int> getTotalUnreadCount() async {
    final userId = _client.auth.currentUser!.id;
    final rows = await _client
        .from('conversations')
        .select('user_a, unread_count_a, unread_count_b')
        .or('user_a.eq.$userId,user_b.eq.$userId');

    int total = 0;
    for (final row in rows) {
      final isUserA = row['user_a'] == userId;
      total += (isUserA ? row['unread_count_a'] : row['unread_count_b']) as int;
    }
    return total;
  }

  RealtimeChannel subscribeToNewMessages(
    void Function() onNewMessage,
  ) {
    final userId = _client.auth.currentUser!.id;
    return _client
        .channel('all_messages:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            // Only react to messages from other users
            if (payload.newRecord['sender_id'] != userId) {
              onNewMessage();
            }
          },
        )
        .subscribe();
  }

  void unsubscribe(RealtimeChannel channel) {
    _client.removeChannel(channel);
  }
}
