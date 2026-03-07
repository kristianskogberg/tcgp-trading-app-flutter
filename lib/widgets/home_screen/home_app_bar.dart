import 'package:flutter/material.dart';

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final bool isEditMode;
  final VoidCallback onToggleEditMode;
  final bool hasActiveFilters;
  final bool hasCards;
  final VoidCallback onOpenFilterSheet;

  const HomeAppBar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.isEditMode,
    required this.onToggleEditMode,
    required this.hasActiveFilters,
    required this.hasCards,
    required this.onOpenFilterSheet,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 12,
      title: SizedBox(
        height: 40,
        child: TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          keyboardType: TextInputType.text,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Search cards...',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 15),
            prefixIcon:
                const Icon(Icons.search, color: Colors.white38, size: 20),
            suffixIcon: ListenableBuilder(
              listenable: searchController,
              builder: (context, _) {
                if (searchController.text.isEmpty) {
                  return const SizedBox.shrink();
                }
                return IconButton(
                  icon: const Icon(Icons.close,
                      color: Colors.white54, size: 18),
                  onPressed: onClearSearch,
                );
              },
            ),
            filled: true,
            fillColor: const Color(0xFF1E1E24),
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            isEditMode ? Icons.edit : Icons.edit_outlined,
            color: isEditMode ? const Color(0xFF02F8AE) : null,
          ),
          onPressed: onToggleEditMode,
        ),
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.tune),
              onPressed: hasCards ? onOpenFilterSheet : null,
            ),
            if (hasActiveFilters)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF02F8AE),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
