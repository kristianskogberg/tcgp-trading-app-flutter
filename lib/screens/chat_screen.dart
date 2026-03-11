import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/models/message.dart';
import 'package:tcgp_trading_app/models/trade_match.dart';
import 'package:tcgp_trading_app/auth/profile_service.dart';
import 'package:tcgp_trading_app/services/card_service.dart';
import 'package:tcgp_trading_app/services/chat_service.dart';
import 'package:tcgp_trading_app/widgets/chat_screen/chat_app_bar.dart';
import 'package:tcgp_trading_app/widgets/chat_screen/chat_input_bar.dart';
import 'package:tcgp_trading_app/widgets/chat_screen/chat_message_area.dart';
import 'package:tcgp_trading_app/widgets/chat_screen/chat_text_bubble.dart';
import 'package:tcgp_trading_app/widgets/chat_screen/chat_trade_bubble.dart';
import 'package:tcgp_trading_app/widgets/chat_screen/chat_friend_id_bubble.dart';
import 'package:tcgp_trading_app/widgets/chat_screen/chat_trade_result_bubble.dart';
import 'package:tcgp_trading_app/widgets/chat_screen/chat_next_steps_bubble.dart';
import 'package:tcgp_trading_app/widgets/shared/app_dialog.dart';
import 'package:tcgp_trading_app/utils/constants.dart';

class ChatScreen extends StatefulWidget {
  final PocketCard? contextCard;
  final PocketCard? matchCard;
  final TradeMatch? tradeMatch;
  final bool isWantTab;
  final String? offerLanguage;
  final String? receiveLanguage;

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
    this.offerLanguage,
    this.receiveLanguage,
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
        isWantTab = false,
        offerLanguage = null,
        receiveLanguage = null;

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
  final Set<String> _processingTradeIds = {};

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
        onUpdate: _onUpdatedMessage,
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
        await _sendTradeMessage(
          offerCard.id,
          widget.offerLanguage ?? '',
          receiveCard.id,
          widget.receiveLanguage ?? '',
        );
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
    String offerCardId,
    String offerLanguage,
    String receiveCardId,
    String receiveLanguage,
  ) async {
    if (_conversationId == null) return;
    try {
      final message = await _chatService.sendTradeMessage(
        _conversationId!,
        offerCardId,
        offerLanguage,
        receiveCardId,
        receiveLanguage,
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

  void _onUpdatedMessage(Message message) {
    if (!mounted) return;
    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index == -1) return;
    setState(() => _messages[index] = message);
  }

  Future<void> _acceptTrade(Message msg) async {
    if (_processingTradeIds.contains(msg.id)) return;
    setState(() => _processingTradeIds.add(msg.id));
    try {
      await _chatService.updateTradeStatus(msg.id, 'accepted');
      // Update locally immediately
      final parts = msg.content.split(':');
      if (parts.length > 5) {
        parts[5] = 'accepted';
      } else {
        parts.add('accepted');
      }
      _onUpdatedMessage(msg.copyWith(content: parts.join(':')));
      // Send trade result message
      if (_conversationId != null) {
        final tradeParts = msg.content.split(':');
        final offerCardId = tradeParts.length > 1 ? tradeParts[1] : '';
        final receiveCardId = tradeParts.length > 3 ? tradeParts[3] : '';
        final confirmMsg = await _chatService.sendMessage(
          _conversationId!,
          'TRADERESULT:accepted:$_myPlayerName:$offerCardId:$receiveCardId',
        );
        if (mounted && !_messages.any((m) => m.id == confirmMsg.id)) {
          setState(() => _messages.insert(0, confirmMsg));
        }
      }
    } catch (e) {
      debugPrint('Failed to accept trade: $e');
    } finally {
      if (mounted) setState(() => _processingTradeIds.remove(msg.id));
    }
  }

  Future<void> _denyTrade(Message msg) async {
    if (_processingTradeIds.contains(msg.id)) return;
    setState(() => _processingTradeIds.add(msg.id));
    try {
      await _chatService.updateTradeStatus(msg.id, 'denied');
      final parts = msg.content.split(':');
      if (parts.length > 5) {
        parts[5] = 'denied';
      } else {
        parts.add('denied');
      }
      _onUpdatedMessage(msg.copyWith(content: parts.join(':')));
      if (_conversationId != null) {
        final tradeParts = msg.content.split(':');
        final offerCardId = tradeParts.length > 1 ? tradeParts[1] : '';
        final receiveCardId = tradeParts.length > 3 ? tradeParts[3] : '';
        final confirmMsg = await _chatService.sendMessage(
          _conversationId!,
          'TRADERESULT:denied:$_myPlayerName:$offerCardId:$receiveCardId',
        );
        if (mounted && !_messages.any((m) => m.id == confirmMsg.id)) {
          setState(() => _messages.insert(0, confirmMsg));
        }
      }
    } catch (e) {
      debugPrint('Failed to deny trade: $e');
    } finally {
      if (mounted) setState(() => _processingTradeIds.remove(msg.id));
    }
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

  List<String> get _quickMessages => [
        'I sent you a friend request',
        'My in-game name is $_myPlayerName',
        'I sent you the offer',
        'Thanks for the trade!',
        'I already traded that card, sorry'
      ];

  void _showQuickMessages() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF242429),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              vertical: ChatConstants.messageMarginVertical),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Align(
                  alignment: Alignment.center,
                  child: Text(
                    'Quick Messages',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              ..._quickMessages.map((msg) => ListTile(
                    dense: true,
                    title: Text(msg,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14)),
                    onTap: () {
                      Navigator.pop(context);
                      _sendQuickMessage(msg);
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendQuickMessage(String text) async {
    if (_conversationId == null) return;
    try {
      final message = await _chatService.sendMessage(_conversationId!, text);
      if (!mounted) return;
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

  void _showConfirmTradeDialog() {
    showAppDialog(
      context: context,
      title: 'Confirm trade',
      content: const Text('Did you complete the trade in-game?'),
      cancelText: 'Not yet',
      primaryText: 'Confirm',
      centerContent: true,
      onPrimaryAction: () {
        // TODO: handle trade confirmation
      },
    );
  }

  String get _otherPlayerName =>
      widget.tradeMatch?.playerName ?? widget.otherPlayerName ?? 'Unknown';

  String? get _displayIcon => widget.tradeMatch?.icon ?? widget.otherIcon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ChatAppBar(
        displayName: _otherPlayerName,
        displayIcon: _displayIcon,
        lastActiveAt: widget.tradeMatch?.lastActiveAt,
      ),
      body: Column(
        children: [
          Expanded(
            child: ChatMessageArea(
              loading: _loading,
              error: _error,
              messages: _messages,
              hasMore: _hasMore,
              scrollController: _scrollController,
              messageBubbleBuilder: _buildMessageBubble,
              onLoadMore: _loadMore,
            ),
          ),
          ChatInputBar(
            textController: _textController,
            enabled: !_loading && _error == null,
            hasFriendId: _myFriendId.isNotEmpty,
            onSend: _sendMessage,
            onSendFriendId: _sendFriendIdMessage,
            onShowQuickMessages: _showQuickMessages,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message msg) {
    final isMine = msg.senderId == _currentUserId;

    if (msg.content.startsWith('TRADE:')) {
      final parts = msg.content.split(':');
      final offerCardId = parts.length > 1 ? parts[1] : '';
      final offerLang = parts.length > 2 ? parts[2] : '';
      final receiveCardId = parts.length > 3 ? parts[3] : '';
      final receiveLang = parts.length > 4 ? parts[4] : '';
      final status = parts.length > 5 ? parts[5] : 'pending';
      final hasAcceptedTrade = _messages.any((m) =>
          m.content.startsWith('TRADE:') &&
          m.content.split(':').length > 5 &&
          m.content.split(':')[5] == 'accepted');

      return ChatTradeBubble(
        isMine: isMine,
        myPlayerName: _myPlayerName,
        displayName: _otherPlayerName,
        offerCard: _cardMap[offerCardId],
        receiveCard: _cardMap[receiveCardId],
        offerLanguage: offerLang,
        receiveLanguage: receiveLang,
        status: status,
        isProcessing: _processingTradeIds.contains(msg.id),
        hasAcceptedTrade: hasAcceptedTrade,
        createdAt: msg.createdAt,
        onAccept: () => _acceptTrade(msg),
        onDeny: () => _denyTrade(msg),
      );
    }

    if (msg.content.startsWith('TRADERESULT:')) {
      final parts = msg.content.split(':');
      final status = parts.length > 1 ? parts[1] : 'accepted';
      final actorName = parts.length > 2 ? parts[2] : '';
      final offerCardId = parts.length > 3 ? parts[3] : '';
      final receiveCardId = parts.length > 4 ? parts[4] : '';

      final resultBubble = ChatTradeResultBubble(
        status: status,
        actorPlayerName: actorName,
        isMine: isMine,
        offerCard: _cardMap[offerCardId],
        receiveCard: _cardMap[receiveCardId],
        createdAt: msg.createdAt,
      );

      if (status == 'accepted') {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            resultBubble,
            ChatNextStepsBubble(
              onConfirmTrade: () => _showConfirmTradeDialog(),
            ),
          ],
        );
      }

      return resultBubble;
    }

    if (msg.content.startsWith('FRIENDID:')) {
      final parts = msg.content.split(':');
      return ChatFriendIdBubble(
        playerName: parts.length > 1 ? parts[1] : '',
        friendId: parts.length > 2 ? parts[2] : '',
        createdAt: msg.createdAt,
        isMine: isMine,
      );
    }

    return ChatTextBubble(
      content: msg.content,
      createdAt: msg.createdAt,
      isMine: isMine,
    );
  }
}
