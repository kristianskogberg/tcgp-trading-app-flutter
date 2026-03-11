import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/utils/time_format.dart';
import 'package:tcgp_trading_app/utils/constants.dart';

class ChatTradeResultBubble extends StatelessWidget {
  final String status; // 'accepted' or 'denied'
  final String actorPlayerName;
  final bool isMine;
  final PocketCard? offerCard;
  final PocketCard? receiveCard;
  final DateTime createdAt;

  const ChatTradeResultBubble({
    super.key,
    required this.status,
    required this.actorPlayerName,
    required this.isMine,
    required this.offerCard,
    required this.receiveCard,
    required this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    final isAccepted = status == 'accepted';
    final actor = isMine ? 'You' : actorPlayerName;
    final verb = isAccepted ? 'accepted' : 'denied';
    final offerName = offerCard?.name ?? 'Unknown';
    final receiveName = receiveCard?.name ?? 'Unknown';
    final accentColor =
        isAccepted ? const Color(0xFF02F8AE) : const Color(0xFFE57373);

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(
            horizontal: ChatConstants.messageMarginHorizontal,
            vertical: ChatConstants.messageMarginVertical),
        padding: const EdgeInsets.all(ChatConstants.messagePadding),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isAccepted ? Icons.check_circle : Icons.cancel,
                  color: accentColor,
                  size: 14,
                ),
                const SizedBox(width: 5),
                Text(
                  '$actor $verb the trade',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '$offerName for $receiveName',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
