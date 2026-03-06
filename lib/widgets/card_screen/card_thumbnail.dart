import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/models/card.dart';

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
            child: CachedNetworkImage(
              imageUrl: card.imageUrl,
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
                  fontSize: 12,
                  fontWeight: FontWeight.w400),
            ),
          ),
        ),
      ],
    );
  }
}
