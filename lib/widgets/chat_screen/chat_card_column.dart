import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/models/card.dart';

class ChatCardColumn extends StatelessWidget {
  final PocketCard? card;
  final String label;
  final String language;

  const ChatCardColumn({
    super.key,
    required this.card,
    required this.label,
    this.language = '',
  });

  @override
  Widget build(BuildContext context) {
    if (card == null) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(Icons.help_outline, size: 24, color: Colors.white24),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CachedNetworkImage(
                imageUrl: card!.imageUrl,
                height: 150,
                fit: BoxFit.contain,
                placeholder: (context, url) => Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.broken_image, color: Colors.white24),
              ),
            ),
            if (language.isNotEmpty)
              Positioned(
                top: 6,
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
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white54),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
