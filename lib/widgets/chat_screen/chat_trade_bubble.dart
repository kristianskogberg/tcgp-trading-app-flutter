import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/utils/time_format.dart';
import 'package:tcgp_trading_app/widgets/shared/trade_card_pair.dart';
import 'package:tcgp_trading_app/utils/constants.dart';

class ChatTradeBubble extends StatelessWidget {
  final bool isMine;
  final String myPlayerName;
  final String displayName;
  final PocketCard? offerCard;
  final PocketCard? receiveCard;
  final String offerLanguage;
  final String receiveLanguage;
  final String status;
  final bool isProcessing;
  final DateTime createdAt;
  final VoidCallback onAccept;
  final VoidCallback onDeny;

  const ChatTradeBubble({
    super.key,
    required this.isMine,
    required this.myPlayerName,
    required this.displayName,
    required this.offerCard,
    required this.receiveCard,
    this.offerLanguage = '',
    this.receiveLanguage = '',
    required this.status,
    required this.isProcessing,
    required this.createdAt,
    required this.onAccept,
    required this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    final isAccepted = status == 'accepted';
    final isDenied = status == 'denied';
    final isPending = status == 'pending';

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(
            horizontal: ChatConstants.messageMarginHorizontal,
            vertical: ChatConstants.messageMarginVertical),
        padding: const EdgeInsets.all(ChatConstants.messagePadding),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: isAccepted
              ? const Color(0xFF02F8AE).withOpacity(0.15)
              : isDenied
                  ? Colors.redAccent.withOpacity(0.10)
                  : const Color(0xFF1E1E24),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isAccepted
                ? const Color(0xFF02F8AE).withOpacity(0.6)
                : isDenied
                    ? Colors.redAccent.withOpacity(0.3)
                    : const Color(0xFF02F8AE).withOpacity(0.3),
            width: isAccepted ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isAccepted)
              const Row(
                children: [
                  Icon(Icons.check_circle, size: 14, color: Color(0xFF02F8AE)),
                  SizedBox(width: 4),
                  Text(
                    'Accepted',
                    style: TextStyle(
                      color: Color(0xFF02F8AE),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            else if (isDenied)
              const Row(
                children: [
                  Icon(Icons.cancel, size: 14, color: Colors.white38),
                  SizedBox(width: 4),
                  Text(
                    'Denied',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            else
              Text(
                isMine
                    ? '$myPlayerName proposed a trade'
                    : '$displayName proposed a trade',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            const SizedBox(height: 8),
            TradeCardPair(
              leftCard: offerCard,
              rightCard: receiveCard,
              leftTopLabel: isMine ? myPlayerName : displayName,
              rightTopLabel: isMine ? displayName : myPlayerName,
              leftBottomLabel: offerCard?.name,
              rightBottomLabel: receiveCard?.name,
              leftLanguage: offerLanguage,
              rightLanguage: receiveLanguage,
              cardHeight: 150,
            ),
            if (!isMine && isPending) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 32,
                      child: OutlinedButton(
                        onPressed: isProcessing ? null : onDeny,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          foregroundColor: Colors.white70,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child:
                            const Text('Deny', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 32,
                      child: ElevatedButton(
                        onPressed: isProcessing ? null : onAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF02F8AE),
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Accept',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
    );
  }
}
