import 'package:flutter/material.dart';

class ActiveFilterChips extends StatelessWidget {
  final Set<String> selectedSets;
  final Set<String> selectedRarities;
  final Set<String> selectedPacks;
  final void Function(String type, String value) onRemoveFilter;

  const ActiveFilterChips({
    super.key,
    required this.selectedSets,
    required this.selectedRarities,
    required this.selectedPacks,
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

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: chips,
      ),
    );
  }

  Widget _buildDismissibleChip(String label, String type) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: true,
        onSelected: (_) => onRemoveFilter(type, label),
        selectedColor: const Color(0xFF02F8AE),
        deleteIcon: const Icon(Icons.close, size: 16),
        onDeleted: () => onRemoveFilter(type, label),
        deleteIconColor: Colors.white70,
        labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF02F8AE)),
        ),
      ),
    );
  }
}
