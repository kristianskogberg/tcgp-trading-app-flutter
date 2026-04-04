import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:tcgp_trading_app/config/app_colors.dart';
import 'package:tcgp_trading_app/widgets/shared/card_search_bar.dart';

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final bool isEditMode;
  final VoidCallback? onToggleEditMode;
  final bool hasActiveFilters;
  final bool hasCards;
  final VoidCallback onOpenFilterSheet;

  const HomeAppBar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.isEditMode,
    this.onToggleEditMode,
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
      title: CardSearchBar(
        controller: searchController,
        onChanged: onSearchChanged,
        onClear: onClearSearch,
      ),
      actions: [
        IconButton(
          icon: PhosphorIcon(
            isEditMode
                ? PhosphorIcons.notePencil(PhosphorIconsStyle.fill)
                : PhosphorIcons.notePencil(),
            color: isEditMode ? AppColors.primary : null,
          ),
          onPressed: onToggleEditMode,
        ),
        Stack(
          children: [
            IconButton(
              icon: PhosphorIcon(PhosphorIcons.faders()),
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
                    color: AppColors.primary,
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
