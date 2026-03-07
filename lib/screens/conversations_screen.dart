import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/screens/chat_screen.dart';
import 'package:tcgp_trading_app/services/chat_service.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final _chatService = ChatService();
  List<Map<String, dynamic>>? _conversations;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    try {
      final conversations = await _chatService.getConversations();
      if (!mounted) return;
      setState(() {
        _conversations = conversations;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _openConversation(Map<String, dynamic> conversation) {
    final conversationId = conversation['id'] as String;
    final otherUserId = conversation['other_user_id'] as String;
    final otherPlayerName = conversation['other_player_name'] as String;

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen.fromConversation(
          conversationId: conversationId,
          otherUserId: otherUserId,
          otherPlayerName: otherPlayerName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_conversations == null || _conversations!.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 48, color: Colors.white24),
            SizedBox(height: 12),
            Text(
              'No conversations yet',
              style: TextStyle(fontSize: 14, color: Colors.white38),
            ),
            SizedBox(height: 4),
            Text(
              'Start a chat from a trade match',
              style: TextStyle(fontSize: 12, color: Colors.white24),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _loading = true);
        await _loadConversations();
      },
      child: ListView.builder(
        itemCount: _conversations!.length,
        itemBuilder: (context, index) =>
            _buildConversationTile(_conversations![index]),
      ),
    );
  }

  Widget _buildConversationTile(Map<String, dynamic> conversation) {
    final playerName = conversation['other_player_name'] as String;
    final lastMessage = conversation['last_message_text'] as String?;
    final lastMessageAt = conversation['last_message_at'] != null
        ? DateTime.parse(conversation['last_message_at'] as String)
        : null;

    return ListTile(
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: const Color(0xFF2A2A30),
        child: const Icon(Icons.person, size: 22, color: Colors.white54),
      ),
      title: Text(
        playerName,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: lastMessage != null
          ? Text(
              lastMessage,
              style: const TextStyle(fontSize: 13, color: Colors.white54),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: lastMessageAt != null
          ? Text(
              _formatRelativeTime(lastMessageAt.toLocal()),
              style: const TextStyle(fontSize: 11, color: Colors.white38),
            )
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: () {
        try {
          _openConversation(conversation);
        } catch (e) {
          debugPrint('Failed to open conversation: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to open conversation: $e')),
          );
        }
      },
    );
  }

  String _formatRelativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }
}
