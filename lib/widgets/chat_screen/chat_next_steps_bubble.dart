import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/utils/constants.dart';

class ChatNextStepsBubble extends StatelessWidget {
  final VoidCallback? onConfirmTrade;

  const ChatNextStepsBubble({super.key, this.onConfirmTrade});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(
            horizontal: ChatConstants.messageMarginHorizontal,
            vertical: ChatConstants.messageMarginVertical),
        padding: const EdgeInsets.all(ChatConstants.messagePadding),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E24),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF02F8AE).withOpacity(0.15),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Next steps',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            const _StepItem(
              number: 1,
              text: 'Share Friend IDs and add each other as friends in-game',
            ),
            const _StepItem(
              number: 2,
              text: 'Complete the trade in-game',
            ),
            _StepItem(
              number: 3,
              isLast: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Confirm the trade',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                  if (onConfirmTrade != null) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 26,
                      child: OutlinedButton(
                        onPressed: onConfirmTrade,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Color(0xFF02F8AE),
                            width: 1,
                          ),
                          foregroundColor: const Color(0xFF02F8AE),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: const Text(
                          'Confirm',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final int number;
  final String? text;
  final Widget? child;
  final bool isLast;

  const _StepItem({
    required this.number,
    this.text,
    this.child,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = child ??
        Text(
          text ?? '',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            height: 1.3,
          ),
        );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFF02F8AE).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      color: Color(0xFF02F8AE),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: const Color(0xFF02F8AE).withOpacity(0.15),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: 2,
                bottom: isLast ? 0 : 14,
              ),
              child: content,
            ),
          ),
        ],
      ),
    );
  }
}
