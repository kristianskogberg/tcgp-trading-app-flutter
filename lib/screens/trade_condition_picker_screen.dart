import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:tcgp_trading_app/config/app_colors.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/models/home_mode.dart';
import 'package:tcgp_trading_app/services/card_service.dart';
import 'package:tcgp_trading_app/utils/rarity_utils.dart';
import 'package:tcgp_trading_app/widgets/shared/active_filter_chips.dart';
import 'package:tcgp_trading_app/widgets/shared/card_badge.dart';
import 'package:tcgp_trading_app/widgets/shared/card_grid.dart';
import 'package:tcgp_trading_app/widgets/shared/card_tile.dart';
import 'package:tcgp_trading_app/widgets/shared/filter_sheet.dart';
import 'package:tcgp_trading_app/widgets/shared/sort_selector.dart';
import 'package:tcgp_trading_app/widgets/shared/app_dialog.dart';
import 'package:tcgp_trading_app/widgets/shared/card_language_button.dart';
import 'package:tcgp_trading_app/widgets/shared/card_search_bar.dart';
import 'package:tcgp_trading_app/widgets/shared/language_picker_sheet.dart';
import 'package:tcgp_trading_app/widgets/shared/optimized_card_image.dart';

const int maxSelectedCards = 10;

class TradeConditionPickerScreen extends StatefulWidget {
  final PocketCard listedCard;
  final Map<String, Set<String>> initialSelection;

  const TradeConditionPickerScreen({
    super.key,
    required this.listedCard,
    required this.initialSelection,
  });

  @override
  State<TradeConditionPickerScreen> createState() =>
      _TradeConditionPickerScreenState();
}

class _TradeConditionPickerScreenState
    extends State<TradeConditionPickerScreen> {
  late Map<String, Set<String>> _selected; // cardId -> language codes
  List<PocketCard> _allCards = [];
  List<PocketCard> _filteredCards = [];
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _selectedScrollController = ScrollController();
  Timer? _debounceTimer;

  // Sort & filter
  bool _sortAscending = false;
  Set<String> _selectedSets = {};
  Set<String> _selectedPacks = {};
  Set<String> _selectedCardTypes = {};

  // Available filter options (populated from card data)
  List<String> _availableSets = [];
  List<String> _availablePacks = [];
  List<String> _availableCardTypes = [];

  bool get _hasActiveFilters =>
      _selectedSets.isNotEmpty ||
      _selectedPacks.isNotEmpty ||
      _selectedCardTypes.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelection.map(
      (k, v) => MapEntry(k, Set<String>.from(v)),
    );
    _loadCards();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _selectedScrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _loadCards() {
    final cardMap = CardService().getCardMap();
    _allCards = cardMap.values.where((card) {
      // Same rarity only
      if (card.rarity != widget.listedCard.rarity) return false;
      // Exclude the listed card itself
      if (card.id == widget.listedCard.id) return false;
      // Exclude untradable cards
      if (isCardUntradable(card.rarity, card.pack)) return false;
      return true;
    }).toList();

    // Populate available filter options
    final sets = <String>{};
    final packs = <String>{};
    final cardTypes = <String>{};
    for (final card in _allCards) {
      sets.add(card.set);
      if (card.pack.isNotEmpty) packs.add(card.pack);
      if (card.cardType.isNotEmpty) cardTypes.add(card.cardType);
    }
    _availableSets = sets.toList()..sort();
    _availablePacks = packs.toList()..sort();
    _availableCardTypes = cardTypes.toList()..sort();

    _applyFilter();
  }

  void _onSearchChanged(String _) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _applyFilter();
    });
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCards = _allCards.where((card) {
        if (query.isNotEmpty && !card.name.toLowerCase().contains(query)) {
          return false;
        }
        if (_selectedSets.isNotEmpty && !_selectedSets.contains(card.set)) {
          return false;
        }
        if (_selectedPacks.isNotEmpty && !_selectedPacks.contains(card.pack)) {
          return false;
        }
        if (_selectedCardTypes.isNotEmpty &&
            !_selectedCardTypes.contains(card.cardType)) {
          return false;
        }
        return true;
      }).toList()
        ..sort((a, b) {
          final aPromo = a.set.startsWith('P-');
          final bPromo = b.set.startsWith('P-');
          if (aPromo != bPromo) return aPromo ? 1 : -1;
          final setCmp = a.set.compareTo(b.set);
          if (setCmp != 0) return _sortAscending ? setCmp : -setCmp;
          return a.number.compareTo(b.number);
        });
    });
  }

  void _removeFilter(String type, String value) {
    setState(() {
      switch (type) {
        case 'set':
          _selectedSets.remove(value);
        case 'pack':
          _selectedPacks.remove(value);
        case 'cardType':
          _selectedCardTypes.remove(value);
      }
    });
    _applyFilter();
  }

  void _openFilterSheet() {
    openFilterSheet(
      context: context,
      availableSets: _availableSets,
      availableRarities: const [],
      availablePacks: _availablePacks,
      availableCardTypes: _availableCardTypes,
      selectedSets: _selectedSets,
      selectedRarities: const {},
      selectedPacks: _selectedPacks,
      selectedCardTypes: _selectedCardTypes,
      lockedRarities: {widget.listedCard.rarity},
      onApply: (sets, rarities, packs, cardTypes) {
        setState(() {
          _selectedSets = sets;
          _selectedPacks = packs;
          _selectedCardTypes = cardTypes;
        });
        _applyFilter();
      },
    );
  }

  void _toggleCard(String cardId) {
    if (!_selected.containsKey(cardId) &&
        _selected.length >= maxSelectedCards) {
      showAppDialog(
        context: context,
        title: 'Limit reached',
        content: const Text(
            'You can select a maximum of 10 cards for a trade condition.'),
        cancelText: 'OK',
        primaryText: 'OK',
        centerContent: true,
      );
      return;
    }
    setState(() {
      if (_selected.containsKey(cardId)) {
        _selected.remove(cardId);
      } else {
        _selected[cardId] = {'ANY'};
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_selectedScrollController.hasClients) return;
          _selectedScrollController.animateTo(
            _selectedScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        });
      }
    });
  }

  Future<void> _showLanguagePicker(String cardId) async {
    final currentLangs = _selected[cardId] ?? {'ANY'};
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      backgroundColor: const Color(0xFF1E1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => LanguagePickerSheet(
        selected: Set.from(currentLangs),
        showAny: true,
        multiSelect: true,
      ),
    );
    if (!mounted) return;
    if (result != null && result.isNotEmpty) {
      setState(() {
        _selected[cardId] = result;
      });
    }
  }

  void _clearAll() {
    setState(() => _selected.clear());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Accepted cards (${_selected.length})',
        ),
        actions: [
          if (_selected.isNotEmpty)
            TextButton(
              onPressed: _clearAll,
              child: const Text(
                'Clear',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(
                context, Map<String, Set<String>>.from(_selected)),
            child: const Text(
              'Save',
              style: TextStyle(
                color: AppColors.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(6, 10, 6, 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E24),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                PhosphorIcon(PhosphorIcons.info(),
                    size: 20, color: Colors.white38),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Select up to $maxSelectedCards cards you would accept in return for your ${widget.listedCard.name}. Leave it empty to accept any card of the same rarity.',
                    style: const TextStyle(fontSize: 13, color: Colors.white54),
                  ),
                ),
              ],
            ),
          ),
          // Context header with listed card + selected cards
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 8, 0, 8),
            color: const Color(0xFF1E1E24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Listed card
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    width: 80,
                    height: 112,
                    child: OptimizedCardImage(
                      imageUrl: widget.listedCard.imageUrl,
                      isThumbnail: true,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // Arrow separator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: PhosphorIcon(
                    PhosphorIcons.arrowsLeftRight(),
                    size: 20,
                    color: Colors.white38,
                  ),
                ),
                // Selected cards list
                Expanded(
                  child: SizedBox(
                    height: 112,
                    child: ListView.separated(
                      controller: _selectedScrollController,
                      scrollDirection: Axis.horizontal,
                      itemCount: _selected.length +
                          (_selected.length < maxSelectedCards ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        // Last item is the dashed placeholder
                        if (index == _selected.length) {
                          return const _DashedPlaceholderCard();
                        }
                        final cardId = _selected.keys.elementAt(index);
                        final langs = _selected[cardId]!;
                        final cardMap = CardService().getCardMap();
                        final card = cardMap[cardId];
                        if (card == null) {
                          return const SizedBox.shrink();
                        }
                        return GestureDetector(
                          onTap: () => _toggleCard(cardId),
                          child: SizedBox(
                            width: 80,
                            height: 112,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: SizedBox(
                                    width: 80,
                                    height: 112,
                                    child: OptimizedCardImage(
                                      imageUrl: card.imageUrl,
                                      isThumbnail: true,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const Positioned(
                                  top: 0,
                                  right: 0,
                                  child: CardBadge(type: CardBadgeType.remove),
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: CardLanguageButton(
                                    languages: langs,
                                    color: AppColors.condition,
                                    rounded: false,
                                    onTap: () => _showLanguagePicker(cardId),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search bar + filter button
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 10, 2, 4),
            child: Row(
              children: [
                Expanded(
                  child: CardSearchBar(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    onClear: () {
                      _searchController.clear();
                      _applyFilter();
                    },
                  ),
                ),
                Stack(
                  children: [
                    IconButton(
                      icon: PhosphorIcon(PhosphorIcons.faders()),
                      onPressed: _openFilterSheet,
                    ),
                    if (_hasActiveFilters)
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
            ),
          ),
          // Sort selector
          SortSelector(
            sortAscending: _sortAscending,
            showQuickFilters: false,
            onSortAscendingChanged: (val) {
              setState(() => _sortAscending = val);
              _applyFilter();
            },
          ),
          // Active filter chips
          if (_hasActiveFilters)
            ActiveFilterChips(
              selectedSets: _selectedSets,
              selectedRarities: const {},
              selectedPacks: _selectedPacks,
              selectedCardTypes: _selectedCardTypes,
              onRemoveFilter: _removeFilter,
            ),
          // Card grid
          Expanded(
            child: CardGrid(
              cards: _filteredCards,
              scrollController: _scrollController,
              bottomPadding: 16,
              tileBuilder: (card) {
                final isSelected = _selected.containsKey(card.id);
                return CardTile(
                  card: card,
                  mode: HomeMode.picker,
                  isPickerSelected: isSelected,
                  pendingLanguages: _selected[card.id] ?? const {'ANY'},
                  onPickerTap: () => _toggleCard(card.id),
                  onPickerLanguageTap:
                      isSelected ? () => _showLanguagePicker(card.id) : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedPlaceholderCard extends StatelessWidget {
  const _DashedPlaceholderCard();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: CustomPaint(
        painter: _DashedBorderPainter(),
        child: const SizedBox(width: 80, height: 112),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(6),
    );

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().first;
    var distance = 0.0;

    while (distance < metrics.length) {
      final end = (distance + dashWidth).clamp(0.0, metrics.length);
      canvas.drawPath(metrics.extractPath(distance, end), paint);
      distance += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
