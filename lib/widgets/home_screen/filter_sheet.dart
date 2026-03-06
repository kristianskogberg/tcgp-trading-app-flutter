import 'package:flutter/material.dart';

void openFilterSheet({
  required BuildContext context,
  required List<String> availableSets,
  required List<String> availableRarities,
  required List<String> availablePacks,
  required Set<String> selectedSets,
  required Set<String> selectedRarities,
  required Set<String> selectedPacks,
  required void Function(
          Set<String> sets, Set<String> rarities, Set<String> packs)
      onApply,
}) {
  var draftSets = Set<String>.from(selectedSets);
  var draftRarities = Set<String>.from(selectedRarities);
  var draftPacks = Set<String>.from(selectedPacks);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF141418),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Filters',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          _FilterSection(
                            title: 'Set',
                            options: availableSets,
                            selected: draftSets,
                            onToggle: (val) => setSheetState(() {
                              draftSets.contains(val)
                                  ? draftSets.remove(val)
                                  : draftSets.add(val);
                            }),
                          ),
                          const SizedBox(height: 16),
                          _FilterSection(
                            title: 'Rarity',
                            options: availableRarities,
                            selected: draftRarities,
                            onToggle: (val) => setSheetState(() {
                              draftRarities.contains(val)
                                  ? draftRarities.remove(val)
                                  : draftRarities.add(val);
                            }),
                          ),
                          const SizedBox(height: 16),
                          _FilterSection(
                            title: 'Packs',
                            options: availablePacks,
                            selected: draftPacks,
                            onToggle: (val) => setSheetState(() {
                              draftPacks.contains(val)
                                  ? draftPacks.remove(val)
                                  : draftPacks.add(val);
                            }),
                          ),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      decoration: const BoxDecoration(
                        color: Color(0xFF141418),
                        border: Border(
                          top: BorderSide(color: Colors.white12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setSheetState(() {
                                  draftSets.clear();
                                  draftRarities.clear();
                                  draftPacks.clear();
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: const BorderSide(color: Colors.white24),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Clear All'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                onApply(draftSets, draftRarities, draftPacks);
                                Navigator.pop(context);
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF02F8AE),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Apply'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    },
  );
}

class _FilterSection extends StatelessWidget {
  final String title;
  final List<String> options;
  final Set<String> selected;
  final void Function(String) onToggle;

  const _FilterSection({
    required this.title,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selected.contains(option);
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (_) => onToggle(option),
              selectedColor: const Color(0xFF02F8AE),
              checkmarkColor: Colors.white,
              backgroundColor: const Color(0xFF1E1E24),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF02F8AE) : Colors.white24,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
