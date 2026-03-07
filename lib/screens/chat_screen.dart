import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/models/message.dart';
import 'package:tcgp_trading_app/models/trade_match.dart';
import 'package:tcgp_trading_app/auth/profile_service.dart';
import 'package:tcgp_trading_app/services/card_service.dart';
import 'package:tcgp_trading_app/services/chat_service.dart';
import 'package:tcgp_trading_app/utils/activity_utils.dart';

class ChatScreen extends StatefulWidget {
  final PocketCard? contextCard;
  final PocketCard? matchCard;
  final TradeMatch? tradeMatch;
  final bool isWantTab;

  // For opening from conversations list (no TradeMatch needed)
  final String? conversationId;
  final String? otherUserId;
  final String? otherPlayerName;
  final String? otherIcon;

  const ChatScreen({
    super.key,
    required this.contextCard,
    required this.matchCard,
    required this.tradeMatch,
    required this.isWantTab,
  })  : conversationId = null,
        otherUserId = null,
        otherPlayerName = null,
        otherIcon = null;

  const ChatScreen.fromConversation({
    super.key,
    required String this.conversationId,
    required String this.otherUserId,
    required String this.otherPlayerName,
    this.otherIcon,
  })  : contextCard = null,
        matchCard = null,
        tradeMatch = null,
        isWantTab = false;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _chatService = ChatService();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  String? _conversationId;
  List<Message> _messages = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  RealtimeChannel? _channel;
  String? _error;

  late final Map<String, PocketCard> _cardMap;
  String _myPlayerName = '';
  String _myFriendId = '';

  String get _currentUserId => Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _cardMap = CardService().getCardMap();
    _scrollController.addListener(_onScroll);
    _loadMyPlayerName();
    _initChat();
  }

  Future<void> _loadMyPlayerName() async {
    final profile = await ProfileService().getProfile();
    if (!mounted || profile == null) return;
    setState(() {
      _myPlayerName = profile['player_name'] as String? ?? 'Me';
      _myFriendId = profile['friend_id']?.toString() ?? '';
    });
  }

  @override
  void dispose() {
    if (_channel != null) _chatService.unsubscribe(_channel!);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    try {
      String conversationId;

      if (widget.conversationId != null) {
        // Opened from conversations list — already have an ID
        conversationId = widget.conversationId!;
      } else {
        // Opened from trade match — create or fetch conversation
        conversationId = await _chatService.getOrCreateConversation(
          widget.tradeMatch!.userId,
        );
      }

      final messages = await _chatService.getMessages(conversationId);

      if (!mounted) return;

      final channel = _chatService.subscribeToMessages(
        conversationId,
        _onNewMessage,
      );

      setState(() {
        _conversationId = conversationId;
        _messages = messages;
        _channel = channel;
        _hasMore = messages.length >= 30;
        _loading = false;
      });

      // Auto-send trade message when opened from trade section
      if (widget.conversationId == null) {
        final offerCard =
            widget.isWantTab ? widget.matchCard! : widget.contextCard!;
        final receiveCard =
            widget.isWantTab ? widget.contextCard! : widget.matchCard!;
        await _sendTradeMessage(offerCard.id, receiveCard.id);
      }
    } catch (e) {
      debugPrint('ChatScreen._initChat error: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load chat: $e';
        _loading = false;
      });
    }
  }

  Future<void> _sendTradeMessage(
      String offerCardId, String receiveCardId) async {
    if (_conversationId == null) return;
    try {
      final message = await _chatService.sendTradeMessage(
        _conversationId!,
        offerCardId,
        receiveCardId,
      );
      if (!mounted) return;
      if (!_messages.any((m) => m.id == message.id)) {
        setState(() => _messages.insert(0, message));
      }
    } catch (e) {
      debugPrint('Failed to send trade message: $e');
    }
  }

  void _onNewMessage(Message message) {
    if (!mounted) return;
    // Deduplicate (own messages already added from sendMessage response)
    if (_messages.any((m) => m.id == message.id)) return;
    setState(() => _messages.insert(0, message));
  }

  void _onScroll() {
    if (_loadingMore || !_hasMore || _conversationId == null) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_messages.isEmpty) return;
    setState(() => _loadingMore = true);

    try {
      final older = await _chatService.getMessages(
        _conversationId!,
        before: _messages.last.createdAt,
      );

      if (!mounted) return;
      setState(() {
        _messages.addAll(older);
        _hasMore = older.length >= 30;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _conversationId == null) return;

    _textController.clear();

    try {
      final message = await _chatService.sendMessage(_conversationId!, text);
      if (!mounted) return;
      // Add if not already present (realtime might have delivered it first)
      if (!_messages.any((m) => m.id == message.id)) {
        setState(() => _messages.insert(0, message));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
      );
    }
  }

  Future<void> _sendFriendIdMessage() async {
    if (_conversationId == null || _myFriendId.isEmpty) return;
    try {
      final message = await _chatService.sendMessage(
        _conversationId!,
        'FRIENDID:$_myPlayerName:$_myFriendId',
      );
      if (!mounted) return;
      if (!_messages.any((m) => m.id == message.id)) {
        setState(() => _messages.insert(0, message));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send Friend ID')),
      );
    }
  }

  String get _displayName =>
      widget.tradeMatch?.playerName ?? widget.otherPlayerName ?? 'Unknown';

  String? get _displayIcon => widget.tradeMatch?.icon ?? widget.otherIcon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            color: const Color(0xFF242429),
            surfaceTintColor: Colors.transparent,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            position: PopupMenuPosition.under,
            onSelected: (_) {},
            itemBuilder: (context) => [
              const PopupMenuItem(
                height: 44,
                value: 'view_profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 20, color: Colors.white70),
                    SizedBox(width: 12),
                    Text('View profile',
                        style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              const PopupMenuItem(
                height: 44,
                value: 'block',
                child: Row(
                  children: [
                    Icon(Icons.block, size: 20, color: Colors.white70),
                    SizedBox(width: 12),
                    Text('Block user', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ],
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF2A2A30),
              backgroundImage: _displayIcon != null
                  ? AssetImage('images/profile/$_displayIcon')
                  : null,
              child: _displayIcon == null
                  ? Text(
                      _displayName.isNotEmpty
                          ? _displayName[0].toUpperCase()
                          : '?',
                      style:
                          const TextStyle(fontSize: 16, color: Colors.white70),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.tradeMatch != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                activityColor(widget.tradeMatch!.lastActiveAt),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          activityLabel(widget.tradeMatch!.lastActiveAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageArea()),
          SafeArea(
            bottom: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
              color: const Color(0xFF1E1E24),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _loading || _error != null
                        ? null
                        : _sendFriendIdMessage,
                    icon: Icon(
                      Icons.person_add_outlined,
                      color: _loading || _error != null
                          ? Colors.white24
                          : const Color(0xFF02F8AE),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      enabled: !_loading && _error == null,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      maxLength: 100,
                      maxLines: 4,
                      minLines: 1,
                      buildCounter: (context,
                              {required currentLength,
                              required isFocused,
                              required maxLength}) =>
                          null,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: const TextStyle(
                            color: Colors.white24, fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFF2A2A30),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _loading || _error != null ? null : _sendMessage,
                    icon: Icon(
                      Icons.send_rounded,
                      color: _loading || _error != null
                          ? Colors.white24
                          : const Color(0xFF02F8AE),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageArea() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.white24),
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(fontSize: 14, color: Colors.white38)),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 48, color: Colors.white24),
            SizedBox(height: 12),
            Text(
              'Send a message to start the conversation',
              style: TextStyle(fontSize: 14, color: Colors.white38),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _messages.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          if (!_loadingMore) _loadMore();
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
                child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )),
          );
        }
        return _buildMessageBubble(_messages[index]);
      },
    );
  }

  Widget _buildMessageBubble(Message msg) {
    final isMine = msg.senderId == _currentUserId;

    // Detect special messages
    if (msg.content.startsWith('TRADE:')) {
      return _buildTradeMessageBubble(msg, isMine);
    }
    if (msg.content.startsWith('FRIENDID:')) {
      return _buildFriendIdMessageBubble(msg, isMine);
    }

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFF02F8AE) : const Color(0xFF2A2A30),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isMine ? 12 : 0),
            bottomRight: Radius.circular(isMine ? 0 : 12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              msg.content,
              style: TextStyle(
                color: isMine ? Colors.black : Colors.white,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _formatTime(msg.createdAt.toLocal()),
              style: TextStyle(
                fontSize: 10,
                color: isMine ? Colors.black45 : Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTradeMessageBubble(Message msg, bool isMine) {
    final parts = msg.content.split(':');
    // TRADE:offerCardId:receiveCardId
    final offerCardId = parts.length > 1 ? parts[1] : '';
    final receiveCardId = parts.length > 2 ? parts[2] : '';
    final offerCard = _cardMap[offerCardId];
    final receiveCard = _cardMap[receiveCardId];

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E24),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF02F8AE).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isMine
                  ? '$_myPlayerName proposed a trade'
                  : '$_displayName proposed a trade',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    child: _buildCardColumn(
                        offerCard, isMine ? _myPlayerName : _displayName)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(Icons.swap_horiz,
                      size: 32, color: Color(0xFF02F8AE)),
                ),
                Expanded(
                    child: _buildCardColumn(
                        receiveCard, isMine ? _displayName : _myPlayerName)),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                _formatTime(msg.createdAt.toLocal()),
                style: const TextStyle(fontSize: 10, color: Colors.white38),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendIdMessageBubble(Message msg, bool isMine) {
    // FRIENDID:playerName:friendId
    final parts = msg.content.split(':');
    final playerName = parts.length > 1 ? parts[1] : '';
    final friendId = parts.length > 2 ? parts[2] : '';

    String formatFriendId(String id) {
      final digits = id.replaceAll(RegExp(r'\D'), '');
      final buf = StringBuffer();
      for (var i = 0; i < digits.length; i++) {
        if (i > 0 && i % 4 == 0) buf.write('-');
        buf.write(digits[i]);
      }
      return buf.toString();
    }

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E24),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF02F8AE).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              playerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    formatFriendId(friendId),
                    style: const TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: friendId));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Friend ID copied ($friendId)')),
                      );
                    }
                  },
                  child:
                      const Icon(Icons.copy, size: 16, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                _formatTime(msg.createdAt.toLocal()),
                style: const TextStyle(fontSize: 10, color: Colors.white38),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardColumn(PocketCard? card, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (card != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: card.imageUrl,
              height: 150,
              fit: BoxFit.contain,
              placeholder: (context, url) => Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              errorWidget: (context, url, error) =>
                  const Icon(Icons.broken_image, color: Colors.white24),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.white54),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ] else
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(Icons.help_outline, size: 24, color: Colors.white24),
            ),
          ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final time = '$hour:$minute';

    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return time;
    }

    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day) {
      return 'Yesterday $time';
    }

    return '${dt.day}/${dt.month} $time';
  }
}
