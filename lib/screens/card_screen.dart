import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/widgets/card_screen/card_detail_header.dart';
import 'package:tcgp_trading_app/widgets/card_screen/trade_section.dart';

class CardScreen extends StatelessWidget {
  final PocketCard card;
  const CardScreen({super.key, required this.card});

  static const _untradableRarities = {'☆☆☆', '♕', 'Promo'};

  @override
  Widget build(BuildContext context) {
    final isUntradable = _untradableRarities.contains(card.rarity);

    return Scaffold(
      appBar: AppBar(
        title: Text(card.name),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CardDetailHeader(card: card),
            if (isUntradable)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(6, 10, 6, 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E24),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 20, color: Colors.white38),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This card is currently not tradable.',
                        style: const TextStyle(
                            fontSize: 13, color: Colors.white54),
                      ),
                    ),
                  ],
                ),
              )
            else
              TradeSection(card: card),
          ],
        ),
      ),
    );
  }
}
