import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/utils/rarity_utils.dart';
import 'package:tcgp_trading_app/widgets/card_screen/card_detail_header.dart';
import 'package:tcgp_trading_app/widgets/card_screen/trade_section.dart';

class CardScreen extends StatelessWidget {
  final PocketCard card;
  final String? heroTag;
  const CardScreen({super.key, required this.card, this.heroTag});

  @override
  Widget build(BuildContext context) {
    final isUntradable = isCardUntradable(card.rarity, card.pack);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                card.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${card.set} | #${card.number}',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CardDetailHeader(card: card, heroTag: heroTag),
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
                        'This card is currently not available for trading.',
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
