import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:tcgp_trading_app/config/app_colors.dart';

class SortSelector extends StatelessWidget {
  final bool sortAscending;
  final bool showWishlistOnly;
  final bool showOwnedOnly;
  final ValueChanged<bool> onSortAscendingChanged;
  final VoidCallback onToggleWishlist;
  final VoidCallback onToggleOwned;
  final bool showQuickFilters;

  const SortSelector({
    super.key,
    required this.sortAscending,
    this.showWishlistOnly = false,
    this.showOwnedOnly = false,
    required this.onSortAscendingChanged,
    this.onToggleWishlist = _noop,
    this.onToggleOwned = _noop,
    this.showQuickFilters = true,
  });

  static void _noop() {}

  Widget _pill({
    required Widget child,
    required VoidCallback onTap,
    required bool isActive,
    Color activeColor = AppColors.primary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E24),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? activeColor : Colors.transparent,
          ),
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = sortAscending ? 'Oldest set' : 'Newest set';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          const Text(
            'Sort by',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<bool>(
            onSelected: onSortAscendingChanged,
            color: const Color(0xFF2A2A32),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            itemBuilder: (_) => [
              PopupMenuItem(
                height: 44,
                value: false,
                child: Row(
                  children: [
                    PhosphorIcon(PhosphorIcons.sortDescending(),
                        size: 20, color: Colors.white70),
                    SizedBox(width: 12),
                    Text(
                      'Newest set',
                      style: TextStyle(
                        color:
                            !sortAscending ? AppColors.primary : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                height: 44,
                value: true,
                child: Row(
                  children: [
                    PhosphorIcon(PhosphorIcons.sortAscending(),
                        size: 20, color: Colors.white70),
                    SizedBox(width: 12),
                    Text(
                      'Oldest set',
                      style: TextStyle(
                        color:
                            sortAscending ? AppColors.primary : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E24),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(width: 4),
                  PhosphorIcon(
                    PhosphorIcons.caretDown(),
                    size: 11,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
          if (showQuickFilters) ...[
            const Spacer(),
            // Wishlist filter toggle
            _pill(
              isActive: showWishlistOnly,
              activeColor: AppColors.primary,
              onTap: onToggleWishlist,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PhosphorIcon(
                    PhosphorIcons.heartStraight(),
                    size: 12,
                    color:
                        showWishlistOnly ? AppColors.primary : Colors.white54,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Wishlist',
                    style: TextStyle(
                      color:
                          showWishlistOnly ? AppColors.primary : Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            // Owned filter toggle
            _pill(
              isActive: showOwnedOnly,
              activeColor: AppColors.secondary,
              onTap: onToggleOwned,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PhosphorIcon(
                    PhosphorIcons.checkCircle(),
                    size: 12,
                    color: showOwnedOnly ? AppColors.secondary : Colors.white54,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Listings',
                    style: TextStyle(
                      color:
                          showOwnedOnly ? AppColors.secondary : Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
