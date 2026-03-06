import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/utils/rarity_utils.dart';

class CardDetailHeader extends StatelessWidget {
  final PocketCard card;

  const CardDetailHeader({super.key, required this.card});

  Widget _buildTradeCost(String rarity, String pack) {
    final cost = getTradeCost(rarity, pack: pack);
    if (cost == null) {
      return const Text('—', style: TextStyle(color: Colors.white));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(cost, style: const TextStyle(color: Colors.white)),
        const SizedBox(width: 4),
        Image.asset('images/shinedust.png', height: 18, fit: BoxFit.contain),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'card-hero-${card.id}',
            createRectTween: (begin, end) => RectTween(begin: begin, end: end),
            child: CachedNetworkImage(
              imageUrl: card.imageUrl,
              height: 220,
              fit: BoxFit.contain,
              errorWidget: (context, url, error) =>
                  const Icon(Icons.broken_image, size: 100),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  label: 'Set',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.network(
                        'https://nsqcktpyuedsjcjkllll.supabase.co/storage/v1/object/public/tcgp_icons/${card.set.toLowerCase()}.webp',
                        height: 24,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  label: 'Rarity',
                  child: getRarityAsset(card.rarity) != null
                      ? Image.asset(
                          getRarityAsset(card.rarity)!,
                          height: 20,
                          fit: BoxFit.contain,
                        )
                      : Text(card.rarity,
                          style: const TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  label: 'Pack',
                  child: Text(card.pack.isNotEmpty ? card.pack : '—',
                      style: const TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  label: 'Trade cost',
                  child: _buildTradeCost(card.rarity, card.pack),
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
