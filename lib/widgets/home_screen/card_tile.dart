import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/models/home_mode.dart';
import 'package:tcgp_trading_app/screens/card_screen.dart';
import 'package:tcgp_trading_app/utils/languages.dart';
import 'package:tcgp_trading_app/utils/rarity_utils.dart';

class CardTile extends StatefulWidget {
  final PocketCard card;
  final HomeMode mode;
  final bool isPendingWishlist;
  final bool isPendingOwned;
  final Set<String> pendingLanguages;
  final void Function(Set<String> languages)? onWishlistToggle;
  final void Function(Set<String> languages)? onOwnedToggle;
  final void Function(String cardId, Set<String> languages)? onLanguagesChanged;
  final String? heroTag;

  const CardTile({
    super.key,
    required this.card,
    this.mode = HomeMode.browse,
    this.isPendingWishlist = false,
    this.isPendingOwned = false,
    this.pendingLanguages = const {'ANY'},
    this.onWishlistToggle,
    this.onOwnedToggle,
    this.onLanguagesChanged,
    this.heroTag,
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

  String get _languageLabel {
    if (_selectedLanguages.contains('ANY')) return 'Any';
    if (_selectedLanguages.length == 1) {
      return languages[_selectedLanguages.first] ?? _selectedLanguages.first;
    }
    return 'Mixed...';
  }

  Future<void> _showLanguagePicker() async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      backgroundColor: const Color(0xFF1E1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _LanguagePicker(
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
    return _buildEditTile(context);
  }

  Widget _buildCardImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CachedNetworkImage(
        imageUrl: widget.card.imageUrl,
        fit: BoxFit.contain,
        placeholder: (context, url) => const _CardSkeleton(),
        errorWidget: (context, url, error) =>
            const Icon(Icons.broken_image, color: Colors.white24),
      ),
    );
  }

  Widget _buildBrowseTile(BuildContext context) {
    return GestureDetector(
      onTap: () => _navigateToCard(context),
      child: Hero(
        tag: widget.heroTag ?? 'card-hero-${widget.card.id}',
        createRectTween: (begin, end) => RectTween(begin: begin, end: end),
        child: _buildCardImage(),
      ),
    );
  }

  Widget _buildEditTile(BuildContext context) {
    final untradable = isCardUntradable(widget.card.rarity, widget.card.pack);

    return Stack(
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: untradable ? 0.6 : 1.0,
            child: _buildCardImage(),
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
                if (_hasPending)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: GestureDetector(
                      onTap: _showLanguagePicker,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A30).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.language,
                                size: 14,
                                color: widget.isPendingWishlist
                                    ? const Color(0xFF02F8AE)
                                    : widget.isPendingOwned
                                        ? Colors.redAccent
                                        : Colors.white),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                _languageLabel,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: widget.isPendingWishlist
                                      ? const Color(0xFF02F8AE)
                                      : widget.isPendingOwned
                                          ? Colors.redAccent
                                          : Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.favorite,
                        isActive: widget.isPendingWishlist,
                        activeColor: const Color(0xFF02F8AE),
                        onTap: () =>
                            widget.onWishlistToggle?.call(_selectedLanguages),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.check_circle,
                        isActive: widget.isPendingOwned,
                        activeColor: Colors.redAccent,
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
  final bool isActive;
  final Color activeColor;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.isActive,
    required this.activeColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A30).withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap == null
              ? Colors.white12
              : isActive
                  ? activeColor
                  : Colors.white38,
        ),
      ),
    );
  }
}

class _LanguagePicker extends StatefulWidget {
  final Set<String> selected;
  final bool showAny;
  final bool multiSelect;

  const _LanguagePicker({
    required this.selected,
    this.showAny = false,
    this.multiSelect = true,
  });

  @override
  State<_LanguagePicker> createState() => _LanguagePickerState();
}

class _LanguagePickerState extends State<_LanguagePicker> {
  late Set<String> _selected;

  bool get _isAnySelected => _selected.contains('ANY');

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.selected);
  }

  void _selectAny() {
    setState(() => _selected = {'ANY'});
  }

  void _toggleLanguage(String key) {
    setState(() {
      if (widget.multiSelect) {
        _selected.remove('ANY');
        if (_selected.contains(key)) {
          _selected.remove(key);
        } else {
          _selected.add(key);
        }
      } else {
        _selected = {key};
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Select language',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (widget.showAny)
                FilterChip(
                  label: const Text('Any'),
                  selected: _isAnySelected,
                  onSelected: (_) => _selectAny(),
                  selectedColor: const Color(0xFF02F8AE).withAlpha(51),
                  checkmarkColor: const Color(0xFF02F8AE),
                  labelStyle: TextStyle(
                    color: _isAnySelected
                        ? const Color(0xFF02F8AE)
                        : Colors.white70,
                    fontSize: 13,
                  ),
                  backgroundColor: const Color(0xFF2A2A32),
                  side: BorderSide(
                    color: _isAnySelected
                        ? const Color(0xFF02F8AE)
                        : Colors.white24,
                  ),
                ),
              ...languages.entries.map((entry) {
                final isSelected =
                    !_isAnySelected && _selected.contains(entry.key);
                return FilterChip(
                  label: Text(entry.value),
                  selected: isSelected,
                  onSelected: (_) => _toggleLanguage(entry.key),
                  selectedColor: const Color(0xFF02F8AE).withAlpha(51),
                  checkmarkColor: const Color(0xFF02F8AE),
                  labelStyle: TextStyle(
                    color:
                        isSelected ? const Color(0xFF02F8AE) : Colors.white70,
                    fontSize: 13,
                  ),
                  backgroundColor: const Color(0xFF2A2A32),
                  side: BorderSide(
                    color:
                        isSelected ? const Color(0xFF02F8AE) : Colors.white24,
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selected.isNotEmpty
                  ? () => Navigator.pop(context, _selected)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF02F8AE),
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.white12,
                disabledForegroundColor: Colors.white38,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
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
