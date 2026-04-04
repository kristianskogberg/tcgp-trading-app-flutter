import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:tcgp_trading_app/config/app_colors.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/models/home_mode.dart';
import 'package:tcgp_trading_app/screens/card_screen.dart';
import 'package:tcgp_trading_app/utils/constants.dart';
import 'package:tcgp_trading_app/utils/rarity_utils.dart';
import 'package:tcgp_trading_app/widgets/shared/card_badge.dart';
import 'package:tcgp_trading_app/widgets/shared/card_language_button.dart';
import 'package:tcgp_trading_app/widgets/shared/language_picker_sheet.dart';
import 'package:tcgp_trading_app/widgets/shared/optimized_card_image.dart';

class CardTile extends StatefulWidget {
  final PocketCard card;
  final HomeMode mode;
  final bool isPendingWishlist;
  final bool isPendingOwned;
  final bool isConditionTarget;
  final Set<String> pendingLanguages;
  final void Function(Set<String> languages)? onWishlistToggle;
  final void Function(Set<String> languages)? onOwnedToggle;
  final void Function(String cardId, Set<String> languages)? onLanguagesChanged;
  final int tradeConditionCount;
  final VoidCallback? onConditionsPressed;
  final String? heroTag;

  // Picker mode params
  final bool isPickerSelected;
  final VoidCallback? onPickerTap;
  final VoidCallback? onPickerLanguageTap;

  const CardTile({
    super.key,
    required this.card,
    this.mode = HomeMode.browse,
    this.isPendingWishlist = false,
    this.isPendingOwned = false,
    this.isConditionTarget = false,
    this.pendingLanguages = const {'ANY'},
    this.onWishlistToggle,
    this.onOwnedToggle,
    this.onLanguagesChanged,
    this.tradeConditionCount = 0,
    this.onConditionsPressed,
    this.heroTag,
    this.isPickerSelected = false,
    this.onPickerTap,
    this.onPickerLanguageTap,
  });

  @override
  State<CardTile> createState() => _CardTileState();
}

class _CardTileState extends State<CardTile> {
  late Set<String> _selectedLanguages;

  @override
  void initState() {
    super.initState();
    _selectedLanguages = Set.from(widget.pendingLanguages);
  }

  @override
  void didUpdateWidget(CardTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pendingLanguages != widget.pendingLanguages) {
      _selectedLanguages = Set.from(widget.pendingLanguages);
    }
  }

  void _navigateToCard(BuildContext context) {
    FocusScope.of(context).unfocus();
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) =>
            CardScreen(card: widget.card, heroTag: widget.heroTag),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  bool get _hasPending => widget.isPendingWishlist || widget.isPendingOwned;

  Future<void> _showLanguagePicker() async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      backgroundColor: const Color(0xFF1E1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => LanguagePickerSheet(
        selected: Set.from(_selectedLanguages),
        showAny: widget.isPendingWishlist,
        multiSelect: !widget.isPendingOwned,
      ),
    );
    if (result != null) {
      setState(() => _selectedLanguages = result);
      widget.onLanguagesChanged?.call(widget.card.id, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == HomeMode.browse) {
      return _buildBrowseTile(context);
    }
    if (widget.mode == HomeMode.picker) {
      return _buildPickerTile(context);
    }
    return _buildEditTile(context);
  }

  Widget _buildCardImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox.expand(
        child: OptimizedCardImage(
          imageUrl: widget.card.imageUrl,
          isThumbnail: true,
          fit: BoxFit.cover,
          placeholder: (context, url) => const _CardSkeleton(),
          errorWidget: (context, url, error) => Container(
            color: const Color(0xFF1A1A1E),
            padding: const EdgeInsets.all(8),
            alignment: Alignment.center,
            child: Text(
              widget.card.name,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: widget.card.name.length > 20 ? 10 : 12,
                color: Colors.white54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrowseTile(BuildContext context) {
    final icons = <Widget>[];
    if (widget.isPendingOwned) {
      icons.add(const CardBadge(type: CardBadgeType.owned));
    } else if (widget.isPendingWishlist) {
      icons.add(const CardBadge(type: CardBadgeType.wishlist));
    }
    if (widget.isConditionTarget) {
      icons.add(const CardBadge(type: CardBadgeType.conditionTarget));
    }
    if (widget.isPendingOwned && widget.tradeConditionCount > 0) {
      icons.add(CardBadge(
        type: CardBadgeType.listedWithConditions,
        count: widget.tradeConditionCount,
      ));
    }

    return GestureDetector(
      onTap: () => _navigateToCard(context),
      child: Stack(
        children: [
          Positioned.fill(
            child: Hero(
              tag: widget.heroTag ?? 'card-hero-${widget.card.id}',
              createRectTween: (begin, end) =>
                  RectTween(begin: begin, end: end),
              child: _buildCardImage(),
            ),
          ),
          if (icons.isNotEmpty)
            Positioned(
              top: 4,
              right: 4,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (int i = 0; i < icons.length; i++) ...[
                    if (i > 0) const SizedBox(height: 2),
                    icons[i],
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPickerTile(BuildContext context) {
    return GestureDetector(
      onTap: widget.onPickerTap,
      child: Stack(
        children: [
          Positioned.fill(child: _buildCardImage()),
          if (widget.isPickerSelected) ...[
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.black
                      .withOpacity(UIConstants.selectedCardOverlayOpacity),
                  border: Border.all(color: AppColors.condition, width: 3),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: const CardBadge(type: CardBadgeType.conditionTarget),
            ),
            Positioned(
              bottom: 3,
              left: 3,
              right: 3,
              child: CardLanguageButton(
                languages: _selectedLanguages,
                color: AppColors.condition,
                onTap: widget.onPickerLanguageTap,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditTile(BuildContext context) {
    final untradable = isCardUntradable(widget.card.rarity, widget.card.pack);

    final chipColor = widget.isPendingWishlist
        ? AppColors.primary
        : widget.isPendingOwned
            ? AppColors.secondary
            : Colors.white38;

    final hasConditions = widget.tradeConditionCount > 0;
    const conditionsColor = AppColors.condition;

    return Stack(
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: untradable ? 0.6 : 1.0,
            child: _buildCardImage(),
          ),
        ),
        if (_hasPending)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.black.withOpacity(UIConstants
                    .selectedCardOverlayOpacity), // selected card overlay opacity
                border: Border.all(color: chipColor, width: 2),
              ),
            ),
          ),
        if (!untradable)
          Positioned(
            left: 4,
            right: 4,
            bottom: 8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: widget.isPendingOwned
                      ? Row(
                          children: [
                            Expanded(
                              child: CardLanguageButton(
                                languages: _selectedLanguages,
                                color: chipColor,
                                onTap: _showLanguagePicker,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: GestureDetector(
                                onTap: widget.onConditionsPressed,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 6, horizontal: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black
                                        .withOpacity(UIConstants.buttonOpacity),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      PhosphorIcon(
                                        hasConditions
                                            ? PhosphorIcons.magnifyingGlass(
                                                PhosphorIconsStyle.fill)
                                            : PhosphorIcons.magnifyingGlass(),
                                        size: 18,
                                        color: conditionsColor,
                                      ),
                                      const SizedBox(width: 3),
                                      if (hasConditions) ...[
                                        Flexible(
                                          child: Text(
                                            '${widget.tradeConditionCount}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: conditionsColor,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ] else ...[
                                        Flexible(
                                          child: Text(
                                            'Any',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: conditionsColor,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : CardLanguageButton(
                          languages: _selectedLanguages,
                          color: chipColor,
                          onTap: _hasPending ? _showLanguagePicker : null,
                        ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: PhosphorIcons.heartStraight(
                            PhosphorIconsStyle.fill),
                        label: 'Want',
                        isActive: widget.isPendingWishlist,
                        activeColor: AppColors.primary,
                        onTap: () =>
                            widget.onWishlistToggle?.call(_selectedLanguages),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _ActionButton(
                        icon:
                            PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                        label: 'Have',
                        isActive: widget.isPendingOwned,
                        activeColor: AppColors.secondary,
                        onTap: () {
                          if (_selectedLanguages.contains('ANY') ||
                              _selectedLanguages.length > 1) {
                            final firstValid = _selectedLanguages
                                .where((l) => l != 'ANY')
                                .firstOrNull;
                            final reset = {firstValid ?? 'ENG'};
                            setState(() => _selectedLanguages = reset);
                            widget.onLanguagesChanged
                                ?.call(widget.card.id, reset);
                          }
                          widget.onOwnedToggle?.call(_selectedLanguages);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    this.label,
    required this.isActive,
    required this.activeColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = onTap == null
        ? Colors.white12
        : isActive
            ? activeColor
            : Colors.white38;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(UIConstants.buttonOpacity),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: effectiveColor),
            if (label != null) ...[
              const SizedBox(height: 2),
              Text(label!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: effectiveColor,
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _CardSkeleton extends StatefulWidget {
  const _CardSkeleton();

  @override
  State<_CardSkeleton> createState() => _CardSkeletonState();
}

class _CardSkeletonState extends State<_CardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _colorAnimation = ColorTween(
      begin: const Color(0xFF1A1A1E),
      end: const Color(0xFF2A2A30),
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ColoredBox(color: _colorAnimation.value!);
      },
    );
  }
}
