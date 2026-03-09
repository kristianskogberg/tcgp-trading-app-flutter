import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/models/home_mode.dart';
import 'package:tcgp_trading_app/widgets/home_screen/card_tile.dart';

class CardGrid extends StatelessWidget {
  final List<PocketCard> cards;
  final ScrollController scrollController;
  final HomeMode mode;
  final bool hasPendingChanges;
  final int pendingCount;
  final bool Function(String) effectiveWishlist;
  final bool Function(String) effectiveOwned;
  final Set<String> Function(String) effectiveLanguages;
  final void Function(String cardId, Set<String> languages) onWishlistToggle;
  final void Function(String cardId, Set<String> languages) onOwnedToggle;
  final void Function(String cardId, Set<String> languages) onLanguagesChanged;
  final VoidCallback onSubmit;

  const CardGrid({
    super.key,
    required this.cards,
    required this.scrollController,
    required this.mode,
    required this.hasPendingChanges,
    required this.pendingCount,
    required this.effectiveWishlist,
    required this.effectiveOwned,
    required this.effectiveLanguages,
    required this.onWishlistToggle,
    required this.onOwnedToggle,
    required this.onLanguagesChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final isEditMode = mode == HomeMode.edit;

    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = (constraints.maxWidth ~/ 180).clamp(3, 4);
            return GridView.builder(
              controller: scrollController,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 0.7,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              padding: EdgeInsets.only(
                left: 6,
                right: 6,
                top: 6,
                bottom: isEditMode && hasPendingChanges ? 72 : 6,
              ),
              itemCount: cards.length,
              itemBuilder: (context, index) {
                final card = cards[index];
                return CardTile(
                  card: card,
                  mode: mode,
                  isPendingWishlist: effectiveWishlist(card.id),
                  isPendingOwned: effectiveOwned(card.id),
                  pendingLanguages: effectiveLanguages(card.id),
                  onWishlistToggle: (langs) => onWishlistToggle(card.id, langs),
                  onOwnedToggle: (langs) => onOwnedToggle(card.id, langs),
                  onLanguagesChanged: onLanguagesChanged,
                );
              },
            );
          },
        ),
        if (isEditMode && hasPendingChanges)
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: ElevatedButton(
              onPressed: onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF02F8AE),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Save change${pendingCount == 1 ? '' : 's'} ($pendingCount)',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
