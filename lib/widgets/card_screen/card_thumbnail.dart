import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/widgets/shared/optimized_card_image.dart';

class CardThumbnail extends StatelessWidget {
  final PocketCard card;
  final String lang;

  const CardThumbnail({super.key, required this.card, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: OptimizedCardImage(
              imageUrl: card.imageUrl,
              isThumbnail: true,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) =>
                  const Center(child: Icon(Icons.broken_image, size: 20)),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(0),
            ),
            child: Text(
              lang,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w400),
            ),
          ),
        ),
      ],
    );
  }
}
