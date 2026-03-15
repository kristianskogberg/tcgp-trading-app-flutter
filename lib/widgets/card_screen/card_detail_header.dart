import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/utils/rarity_utils.dart';
import 'package:tcgp_trading_app/utils/set_image_url.dart';
import 'package:tcgp_trading_app/widgets/shared/optimized_card_image.dart';

class CardDetailHeader extends StatelessWidget {
  final PocketCard card;
  final String? heroTag;

  const CardDetailHeader({super.key, required this.card, this.heroTag});

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
            tag: heroTag ?? 'card-hero-${card.id}',
            createRectTween: (begin, end) => RectTween(begin: begin, end: end),
            child: OptimizedCardImage(
              imageUrl: card.imageUrl,
              isThumbnail: false,
              height: 220,
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
                      CachedNetworkImage(
                        imageUrl: setImageUrl(card.set),
                        height: 30,
                        fit: BoxFit.contain,
                        errorWidget: (context, url, error) => Text(card.set),
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
                  child: _PackInfo(set: card.set, pack: card.pack),
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

class _PackInfo extends StatelessWidget {
  final String set;
  final String pack;

  const _PackInfo({required this.set, required this.pack});

  void _showPackImage(BuildContext context) {
    final imageUrl =
        'https://raw.githubusercontent.com/chase-manning/pokemon-tcg-pocket-cards/main/images/packs/$set-${pack.toLowerCase()}.png';
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Image not available',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = pack.isNotEmpty ? pack : '—';
    final canShowImage = pack.isNotEmpty && pack != 'Any';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(displayName, style: const TextStyle(color: Colors.white)),
        if (canShowImage) ...[
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _showPackImage(context),
            child:
                const Icon(Icons.info_outline, size: 16, color: Colors.white54),
          ),
        ],
      ],
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
