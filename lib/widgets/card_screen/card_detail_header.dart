import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/utils/constants.dart';
import 'package:tcgp_trading_app/utils/rarity_utils.dart';
import 'package:tcgp_trading_app/utils/set_image_url.dart';
import 'package:tcgp_trading_app/widgets/shared/optimized_card_image.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class CardDetailHeader extends StatelessWidget {
  final PocketCard card;
  final String? heroTag;

  const CardDetailHeader({super.key, required this.card, this.heroTag});

  String _tradeCostMessage(String rarity, String pack) {
    final cost = getTradeCost(rarity, pack: pack);
    if (cost == null) return 'Not tradeable';
    return 'Requires $cost Shinedust to trade';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: heroTag ?? 'card-hero-${card.id}',
            createRectTween: (begin, end) => RectTween(begin: begin, end: end),
            // Use the source widget during flight so the thumbnail
            // animates smoothly even before the full-res image loads.
            flightShuttleBuilder:
                (flightContext, animation, direction, fromContext, toContext) =>
                    fromContext.widget,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 220,
                child: AspectRatio(
                  aspectRatio: 367 / 512,
                  child: OptimizedCardImage(
                    imageUrl: card.imageUrl,
                    isThumbnail: false,
                    fadeInDuration: Duration.zero,
                    errorWidget: (context, url, error) =>
                        PhosphorIcon(PhosphorIcons.imageBroken(), size: 100),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  label: 'Card type',
                  child: Text(card.cardType,
                      style: const TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  label: 'Set',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CachedNetworkImage(
                        imageUrl: setImageUrl(card.set),
                        height: UIConstants.setImageHeight,
                        fit: BoxFit.contain,
                        errorWidget: (context, url, error) => Text(card.set),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  label: 'Rarity',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      getRarityAsset(card.rarity) != null
                          ? Image.asset(
                              getRarityAsset(card.rarity)!,
                              height: 20,
                              fit: BoxFit.contain,
                            )
                          : Text(card.rarity,
                              style: const TextStyle(color: Colors.white)),
                      const SizedBox(width: 6),
                      Tooltip(
                        message: _tradeCostMessage(card.rarity, card.pack),
                        preferBelow: false,
                        triggerMode: TooltipTriggerMode.tap,
                        showDuration: const Duration(seconds: 5),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        textStyle: const TextStyle(color: Colors.white),
                        child: PhosphorIcon(
                          PhosphorIcons.info(),
                          size: 14,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  label: 'Pack',
                  child: Text(card.pack,
                      style: const TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _InfoRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.white54)),
        const SizedBox(height: 2),
        child,
      ],
    );
  }
}
