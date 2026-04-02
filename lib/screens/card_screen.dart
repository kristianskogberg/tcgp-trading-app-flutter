import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/models/feedback_submission.dart';
import 'package:tcgp_trading_app/services/feedback_service.dart';
import 'package:tcgp_trading_app/utils/rarity_utils.dart';
import 'package:tcgp_trading_app/widgets/card_screen/card_detail_header.dart';
import 'package:tcgp_trading_app/widgets/card_screen/trade_section.dart';
import 'package:tcgp_trading_app/widgets/shared/app_dialog.dart';

class CardScreen extends StatelessWidget {
  final PocketCard card;
  final String? heroTag;
  const CardScreen({super.key, required this.card, this.heroTag});

  void _showReportDialog(BuildContext context) {
    final controller = TextEditingController();
    showAppDialog(
      context: context,
      title: 'Report card issue',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${card.name} (${card.set} #${card.number})',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLines: 3,
            maxLength: 100,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText:
                  'Describe the issue (e.g. wrong image, incorrect name or set…)',
              hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFF141418),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.white24),
              ),
            ),
          ),
        ],
      ),
      primaryText: 'Submit',
      onPrimaryAction: () {
        final description = controller.text.trim();
        if (description.isEmpty) return;
        FeedbackService()
            .submitFeedback(
          type: FeedbackType.cardReport,
          description: description,
          cardId: card.id,
        )
            .then((_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Report submitted. Thank you!')),
            );
          }
        });
      },
    );
  }

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
        actions: [
          PopupMenuButton<String>(
            icon: PhosphorIcon(PhosphorIcons.dotsThreeVertical()),
            color: const Color(0xFF242429),
            surfaceTintColor: Colors.transparent,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            position: PopupMenuPosition.under,
            onSelected: (value) {
              if (value == 'report') {
                _showReportDialog(context);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                height: 44,
                value: 'report',
                child: Row(
                  children: [
                    PhosphorIcon(PhosphorIcons.flag(),
                        size: 20, color: Colors.white70),
                    SizedBox(width: 12),
                    Text('Report an issue',
                        style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ],
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
                    PhosphorIcon(PhosphorIcons.info(),
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
