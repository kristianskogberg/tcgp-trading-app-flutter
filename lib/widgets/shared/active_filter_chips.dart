import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:tcgp_trading_app/config/app_colors.dart';
import 'package:tcgp_trading_app/utils/rarity_utils.dart';
import 'package:tcgp_trading_app/widgets/shared/set_logo_label.dart';

class ActiveFilterChips extends StatelessWidget {
  final Set<String> selectedSets;
  final Set<String> selectedRarities;
  final Set<String> selectedPacks;
  final Set<String> selectedCardTypes;
  final void Function(String type, String value) onRemoveFilter;

  const ActiveFilterChips({
    super.key,
    required this.selectedSets,
    required this.selectedRarities,
    required this.selectedPacks,
    required this.selectedCardTypes,
    required this.onRemoveFilter,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    for (final s in selectedSets) {
      chips.add(_buildDismissibleChip(s, 'set'));
    }
    for (final r in selectedRarities) {
      chips.add(_buildDismissibleChip(r, 'rarity'));
    }
    for (final p in selectedPacks) {
      chips.add(_buildDismissibleChip(p, 'pack'));
    }
    for (final ct in selectedCardTypes) {
      chips.add(_buildDismissibleChip(ct, 'cardType'));
    }
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: chips,
      ),
    );
  }

  Widget _buildChipLabel(String label, String type) {
    if (type == 'rarity') {
      final asset = getRarityAsset(label);
      if (asset != null) {
        return Image.asset(asset, height: 16);
      }
    }
    if (type == 'set') {
      return SetLogoLabel(
        setId: label,
        fallbackColor: AppColors.primary,
        width: 64,
        height: 20,
      );
    }
    if (type == 'cardType') {
      return Text(label);
    }
    return Text(label);
  }

  Widget _buildDismissibleChip(String label, String type) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: _buildChipLabel(label, type),
        selected: true,
        onSelected: (_) => onRemoveFilter(type, label),
        selectedColor: const Color(0xFF1E1E24),
        checkmarkColor: AppColors.primary,
        deleteIcon: PhosphorIcon(PhosphorIcons.x(), size: 16),
        onDeleted: () => onRemoveFilter(type, label),
        deleteIconColor: Colors.white70,
        labelStyle: const TextStyle(color: AppColors.primary, fontSize: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}
