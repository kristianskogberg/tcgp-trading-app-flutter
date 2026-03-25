import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/screens/chat_screen.dart';
import 'package:tcgp_trading_app/services/chat_service.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({
    super.key,
    this.refreshNotifier,
    this.onUnreadChanged,
  });

  final ValueNotifier<int>? refreshNotifier;
  final VoidCallback? onUnreadChanged;

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final _chatService = ChatService();
  List<Map<String, dynamic>>? _conversations;
  bool _loading = true;
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: _onRefresh,
    );
    _loadConversations();
    widget.refreshNotifier?.addListener(_onRefresh);
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    widget.refreshNotifier?.removeListener(_onRefresh);
    super.dispose();
  }

  void _onRefresh() {
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
    } catch (e) {
      debugPrint('Failed to load conversations: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openConversation(Map<String, dynamic> conversation) async {
    final conversationId = conversation['id'] as String;
    final otherUserId = conversation['other_user_id'] as String;
    final otherPlayerName = conversation['other_player_name'] as String;
    final otherIcon = conversation['other_icon'] as String?;

    if (!mounted) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen.fromConversation(
          conversationId: conversationId,
          otherUserId: otherUserId,
          otherPlayerName: otherPlayerName,
          otherIcon: otherIcon,
        ),
      ),
    );
    if (!mounted) return;
    _loadConversations();
    widget.onUnreadChanged?.call();
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
    final icon = conversation['other_icon'] as String?;
    final lastMessage = conversation['last_message_text'] as String?;
    final lastMessageAt = conversation['last_message_at'] != null
        ? DateTime.parse(conversation['last_message_at'] as String)
        : null;
    final unreadCount = conversation['unread_count'] as int? ?? 0;
    final hasUnread = unreadCount > 0;

    return ListTile(
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: const Color(0xFF2A2A30),
        backgroundImage:
            icon != null ? AssetImage('images/profile/$icon') : null,
        child: icon == null
            ? Text(
                playerName.isNotEmpty ? playerName[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 18, color: Colors.white70),
              )
            : null,
      ),
      title: Text(
        playerName,
        style: TextStyle(
          fontSize: 15,
          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: lastMessage != null
          ? Text(
              lastMessage,
              style: TextStyle(
                fontSize: 13,
                color: hasUnread ? Colors.white : Colors.white54,
                fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (lastMessageAt != null)
            Text(
              _formatRelativeTime(lastMessageAt.toLocal()),
              style: TextStyle(
                fontSize: 11,
                color: hasUnread ? const Color(0xFF02F8AE) : Colors.white38,
              ),
            ),
          if (hasUnread) ...[
            const SizedBox(height: 4),
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF02F8AE),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
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
