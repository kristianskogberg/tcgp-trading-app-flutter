import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:tcgp_trading_app/config/app_colors.dart';
import 'package:tcgp_trading_app/utils/constants.dart';

enum CardBadgeType {
  /// User has wishlisted this card. Black-translucent bg, teal heart icon.
  wishlist,

  /// User owns/has listed this card. Black-translucent bg, blue check-circle icon.
  owned,

  /// Card is a trade condition target. Black-translucent bg, cyan magnifying-glass icon.
  conditionTarget,

  /// There is a pending trade proposal for this card. Black-translucent bg, teal arrows icon.
  pendingTrade,

  /// Remove/close a selected card. Black54 bg, white X icon.
  remove,

  /// In a match list: user has this card on their wishlist. Black-translucent bg, teal heart icon.
  matchWishlisted,

  /// In a match list: user owns/has listed this card. Black-translucent bg, teal check-circle icon.
  matchOwned,

  /// Listed card has specific trade conditions. Blue pill badge with count.
  listedWithConditions,
}

class CardBadge extends StatelessWidget {
  final CardBadgeType type;
  final double size;
  final int? count;

  const CardBadge({super.key, required this.type, this.size = 16, this.count});

  @override
  Widget build(BuildContext context) {
    if (type == CardBadgeType.listedWithConditions && count != null) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: size * 0.375, vertical: 4.0),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(UIConstants.buttonOpacity),
          borderRadius: BorderRadius.circular(size),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(
              PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.fill),
              size: size,
              color: AppColors.primary,
            ),
            SizedBox(width: size * 0.2),
            Text(
              '$count',
              style: TextStyle(
                fontSize: size * 0.75,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: EdgeInsets.all(4.0),
      decoration:
          BoxDecoration(color: _backgroundColor, shape: BoxShape.circle),
      child: PhosphorIcon(_icon, size: size, color: _iconColor),
    );
  }

  Color get _backgroundColor => switch (type) {
        CardBadgeType.remove => Colors.black54,
        _ => Colors.black.withOpacity(UIConstants.buttonOpacity),
      };

  IconData get _icon => switch (type) {
        CardBadgeType.wishlist ||
        CardBadgeType.matchWishlisted =>
          PhosphorIcons.heartStraight(PhosphorIconsStyle.fill),
        CardBadgeType.owned ||
        CardBadgeType.matchOwned =>
          PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
        CardBadgeType.conditionTarget ||
        CardBadgeType.listedWithConditions =>
          PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.bold),
        CardBadgeType.pendingTrade => PhosphorIcons.arrowsLeftRight(),
        CardBadgeType.remove => PhosphorIcons.x(PhosphorIconsStyle.bold),
      };

  Color get _iconColor => switch (type) {
        CardBadgeType.owned ||
        CardBadgeType.listedWithConditions =>
          AppColors.secondary,
        CardBadgeType.conditionTarget => AppColors.condition,
        CardBadgeType.remove => Colors.white,
        _ => AppColors.primary,
      };
}
