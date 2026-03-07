import 'package:flutter/material.dart';

class SortSelector extends StatelessWidget {
  final String currentSort;
  final ValueChanged<String> onSortChanged;

  const SortSelector({
    super.key,
    required this.currentSort,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    const options = [
      ('set', 'Set'),
      ('wishlist', 'Wishlist'),
      ('owned', 'Owned'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          const Text(
            'Sort by',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(width: 8),
          ...options.map((option) {
            final isSelected = currentSort == option.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => onSortChanged(option.$1),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E24),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF02F8AE)
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    option.$2,
                    style: TextStyle(
                      color:
                          isSelected ? const Color(0xFF02F8AE) : Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
