import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/utils/set_image_url.dart';
import 'package:tcgp_trading_app/widgets/shared/optimized_card_image.dart';

/// A reusable widget that displays two cards side by side with a swap icon.
/// Used in both the trade preview dialog and the chat trade bubble.
class TradeCardPair extends StatelessWidget {
  final PocketCard? leftCard;
  final PocketCard? rightCard;
  final String leftTopLabel;
  final String rightTopLabel;
  final String? leftBottomLabel;
  final String? rightBottomLabel;
  final String leftLanguage;
  final String rightLanguage;
  final Color? rightActivityColor;
  final double? cardHeight;

  const TradeCardPair({
    super.key,
    required this.leftCard,
    required this.rightCard,
    required this.leftTopLabel,
    required this.rightTopLabel,
    this.leftBottomLabel,
    this.rightBottomLabel,
    this.leftLanguage = '',
    this.rightLanguage = '',
    this.rightActivityColor,
    this.cardHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildSide(
            card: leftCard,
            topLabel: leftTopLabel,
            bottomLabel: leftBottomLabel,
            language: leftLanguage,
            activityColor: null,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Icon(
            Icons.swap_horiz,
            color: Color(0xFF02F8AE),
            size: 28,
          ),
        ),
        Expanded(
          child: _buildSide(
            card: rightCard,
            topLabel: rightTopLabel,
            bottomLabel: rightBottomLabel,
            language: rightLanguage,
            activityColor: rightActivityColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSide({
    required PocketCard? card,
    required String topLabel,
    required String? bottomLabel,
    required String language,
    required Color? activityColor,
  }) {
    if (card == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTopLabel(topLabel, activityColor),
          const SizedBox(height: 6),
          Container(
            height: cardHeight ?? 150,
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTopLabel(topLabel, activityColor),
        const SizedBox(height: 6),
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: OptimizedCardImage(
                imageUrl: card.imageUrl,
                isThumbnail: true,
                height: cardHeight,
                placeholder: cardHeight != null
                    ? (context, url) => Container(
                          height: cardHeight,
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        )
                    : null,
                errorWidget: cardHeight != null
                    ? (context, url, error) =>
                        const Icon(Icons.broken_image, color: Colors.white24)
                    : null,
              ),
            ),
            if (language.isNotEmpty)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    language,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: CachedNetworkImage(
                  imageUrl: setImageUrl(card.set),
                  height: 20,
                  fit: BoxFit.contain,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  placeholder: (_, __) => const SizedBox(height: 20),
                ),
              ),
            ),
          ],
        ),
        if (bottomLabel != null) ...[
          const SizedBox(height: 6),
          Text(
            bottomLabel,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildTopLabel(String label, Color? activityColor) {
    if (activityColor != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: activityColor,
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.white54),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return Text(
      label,
      style: const TextStyle(fontSize: 11, color: Colors.white54),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );
  }
}
