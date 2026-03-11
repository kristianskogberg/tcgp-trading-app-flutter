import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcgp_trading_app/utils/time_format.dart';
import 'package:tcgp_trading_app/utils/constants.dart';

class ChatFriendIdBubble extends StatelessWidget {
  final String playerName;
  final String friendId;
  final DateTime createdAt;
  final bool isMine;

  const ChatFriendIdBubble({
    super.key,
    required this.playerName,
    required this.friendId,
    required this.createdAt,
    required this.isMine,
  });

  static String _formatFriendId(String id) {
    final digits = id.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write('-');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: IntrinsicWidth(
        child: Container(
          margin: const EdgeInsets.symmetric(
              horizontal: ChatConstants.messageMarginHorizontal,
              vertical: ChatConstants.messageMarginVertical),
          padding: const EdgeInsets.all(ChatConstants.messagePadding),
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
                      _formatFriendId(friendId),
                      style:
                          const TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CopyButton(friendId: friendId),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  formatChatTime(createdAt.toLocal()),
                  style: const TextStyle(fontSize: 10, color: Colors.white38),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CopyButton extends StatefulWidget {
  final String friendId;
  const _CopyButton({required this.friendId});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  Future<void> _onTap() async {
    await Clipboard.setData(ClipboardData(text: widget.friendId));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(Icons.copy,
              size: 16,
              color: _copied ? const Color(0xFF02F8AE) : Colors.white70),
          if (_copied)
            Positioned(
              bottom: 22,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                builder: (context, value, child) =>
                    Opacity(opacity: value, child: child),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A30),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Copied',
                    style: TextStyle(fontSize: 12, color: Color(0xFF02F8AE)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
