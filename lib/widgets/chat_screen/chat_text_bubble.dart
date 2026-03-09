import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/utils/time_format.dart';

class ChatTextBubble extends StatelessWidget {
  final String content;
  final DateTime createdAt;
  final bool isMine;

  const ChatTextBubble({
    super.key,
    required this.content,
    required this.createdAt,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
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
              content,
              style: TextStyle(
                color: isMine ? Colors.black : Colors.white,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              formatChatTime(createdAt.toLocal()),
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
}
