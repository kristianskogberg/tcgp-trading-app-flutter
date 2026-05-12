import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/models/home_mode.dart';
import 'package:tcgp_trading_app/models/pending_card_edit.dart';
import 'package:tcgp_trading_app/services/card_service.dart';
import 'package:tcgp_trading_app/services/user_card_service.dart';
import 'package:tcgp_trading_app/widgets/shared/active_filter_chips.dart';
import 'package:tcgp_trading_app/config/app_colors.dart';
import 'package:tcgp_trading_app/widgets/shared/card_grid.dart';
import 'package:tcgp_trading_app/widgets/shared/card_tile.dart';
import 'package:tcgp_trading_app/widgets/shared/filter_sheet.dart';
import 'package:tcgp_trading_app/widgets/home_screen/home_app_bar.dart';
import 'package:tcgp_trading_app/widgets/shared/sort_selector.dart';
import 'package:tcgp_trading_app/screens/trade_condition_picker_screen.dart';
import 'package:tcgp_trading_app/widgets/shared/app_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<PocketCard>> _cardsFuture;
  final _userCardService = UserCardService();

  // All cards from the data source
  List<PocketCard> _allCards = [];
  // Filtered cards to display
  List<PocketCard> _filteredCards = [];

  // Search
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;

  // Mode
  HomeMode _currentMode = HomeMode.browse;

  // Sort
  bool _sortAscending = false; // false = descending (newest sets first)
  bool _showWishlistOnly = false;
  bool _showOwnedOnly = false;

  // Pending edits for edit mode
  final Map<String, PendingCardEdit> _pendingEdits = {};
  final Set<String> _pendingRemovals = {};
  final Map<String, Map<String, Set<String>>> _pendingConditions = {};

  // Available filter options (extracted from data)
  List<String> _availableSets = [];
  List<String> _availableRarities = [];
  List<String> _availablePacks = [];
  List<String> _availableCardTypes = [];

  // Active filters
  Set<String> _selectedSets = {};
  Set<String> _selectedRarities = {};
  Set<String> _selectedPacks = {};
  Set<String> _selectedCardTypes = {};

  bool get _hasActiveFilters =>
      _selectedSets.isNotEmpty ||
      _selectedRarities.isNotEmpty ||
      _selectedPacks.isNotEmpty ||
      _selectedCardTypes.isNotEmpty;

  bool get _isFiltering =>
      _hasActiveFilters || _searchController.text.isNotEmpty;

  bool get _hasPendingChanges =>
      _pendingEdits.isNotEmpty ||
      _pendingRemovals.isNotEmpty ||
      _pendingConditions.isNotEmpty;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _cardsFuture = CardService().getAllCards();
    _userCardService
        .loadMyCards()
        .catchError((e) => debugPrint('Failed to load user cards: $e'));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Search & Filter logic
  // ---------------------------------------------------------------------------

  void _onSearchChanged(String _) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _applyFilters();
    });
  }

  void _populateCards(List<PocketCard> cards) {
    if (_allCards.isNotEmpty) return; // already populated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyCardData(cards);
      CardService().precacheCardImages();
    });
  }

  void _applyCardData(List<PocketCard> cards) {
    final sets = <String>{};
    final rarities = <String>{};
    final packs = <String>{};
    final cardTypes = <String>{};
    for (final card in cards) {
      sets.add(card.set);
      if (card.rarity.toLowerCase() != "promo") {
        rarities.add(card.rarity);
      }
      if (card.pack.isNotEmpty) packs.add(card.pack);
      if (card.cardType.isNotEmpty) cardTypes.add(card.cardType);
    }
    setState(() {
      _allCards = cards;
      _availableSets = sets.toList()..sort();
      _availableRarities = rarities.toList()..sort();
      _availablePacks = packs.toList()..sort();
      _availableCardTypes = cardTypes.toList()..sort();
    });
    _applyFilters();
  }

  Future<void> _refreshCards() async {
    try {
      final cards = await CardService().getAllCards(forceRefresh: true);
      if (!mounted || cards.isEmpty) return;
      _applyCardData(cards);
    } catch (e) {
      debugPrint('Failed to refresh cards: $e');
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCards = _allCards.where((card) {
        if (query.isNotEmpty && !card.name.toLowerCase().contains(query)) {
          return false;
        }
        if (_selectedSets.isNotEmpty && !_selectedSets.contains(card.set)) {
          return false;
        }
        if (_selectedRarities.isNotEmpty &&
            !_selectedRarities.contains(card.rarity)) {
          return false;
        }
        if (_selectedPacks.isNotEmpty && !_selectedPacks.contains(card.pack)) {
          return false;
        }
        if (_selectedCardTypes.isNotEmpty &&
            !_selectedCardTypes.contains(card.cardType)) {
          return false;
        }
        if (_showWishlistOnly && !_effectiveWishlist(card.id)) return false;
        if (_showOwnedOnly && !_effectiveOwned(card.id)) return false;
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
        case 'rarity':
          _selectedRarities.remove(value);
        case 'pack':
          _selectedPacks.remove(value);
        case 'cardType':
          _selectedCardTypes.remove(value);
      }
    });
    _applyFilters();
  }

  void _openFilterSheet() {
    openFilterSheet(
      context: context,
      availableSets: _availableSets,
      availableRarities: _availableRarities,
      availablePacks: _availablePacks,
      availableCardTypes: _availableCardTypes,
      selectedSets: _selectedSets,
      selectedRarities: _selectedRarities,
      selectedPacks: _selectedPacks,
      selectedCardTypes: _selectedCardTypes,
      onApply: (sets, rarities, packs, cardTypes) {
        setState(() {
          _selectedSets = sets;
          _selectedRarities = rarities;
          _selectedPacks = packs;
          _selectedCardTypes = cardTypes;
        });
        _applyFilters();
      },
    );
  }

  void _onSortAscendingChanged(bool ascending) {
    setState(() => _sortAscending = ascending);
    _applyFilters();
  }

  void _onToggleWishlist() {
    setState(() {
      _showWishlistOnly = !_showWishlistOnly;
      if (_showWishlistOnly) _showOwnedOnly = false;
    });
    _applyFilters();
  }

  void _onToggleOwned() {
    setState(() {
      _showOwnedOnly = !_showOwnedOnly;
      if (_showOwnedOnly) _showWishlistOnly = false;
    });
    _applyFilters();
  }

  // ---------------------------------------------------------------------------
  // Edit mode logic
  // ---------------------------------------------------------------------------

  bool _effectiveWishlist(String cardId) {
    if (_pendingEdits.containsKey('$cardId:wishlist')) return true;
    if (_pendingRemovals.contains('$cardId:wishlist')) return false;
    return _userCardService.isWishlisted(cardId);
  }

  bool _effectiveOwned(String cardId) {
    if (_pendingEdits.containsKey('$cardId:owned')) return true;
    if (_pendingRemovals.contains('$cardId:owned')) return false;
    return _userCardService.isOwned(cardId);
  }

  Set<String> _effectiveLanguages(String cardId) {
    for (final type in ['wishlist', 'owned']) {
      final key = '$cardId:$type';
      if (_pendingEdits.containsKey(key)) {
        return _pendingEdits[key]!.languages;
      }
    }
    for (final type in ['wishlist', 'owned']) {
      final langs = _userCardService.getLanguages(cardId, type);
      if (langs.isNotEmpty) return langs;
    }
    return {'ENG'};
  }

  void _togglePending(String cardId, String type, Set<String> languages) {
    setState(() {
      final key = '$cardId:$type';
      final oppositeType = type == 'wishlist' ? 'owned' : 'wishlist';
      final oppositeKey = '$cardId:$oppositeType';

      final isExisting = type == 'wishlist'
          ? _userCardService.isWishlisted(cardId)
          : _userCardService.isOwned(cardId);

      if (isExisting && !_pendingRemovals.contains(key)) {
        _pendingRemovals.add(key);
        _pendingEdits.remove(key);
      } else if (isExisting && _pendingRemovals.contains(key)) {
        _pendingRemovals.remove(key);
        _pendingEdits.remove(oppositeKey);
      } else if (_pendingEdits.containsKey(key)) {
        _pendingEdits.remove(key);
      } else {
        _pendingEdits.remove(oppositeKey);
        final oppositeExists = oppositeType == 'wishlist'
            ? _userCardService.isWishlisted(cardId)
            : _userCardService.isOwned(cardId);
        if (oppositeExists) {
          _pendingRemovals.add(oppositeKey);
        }
        _pendingEdits[key] = PendingCardEdit(
          cardId: cardId,
          type: type,
          languages: languages,
        );
      }
    });
  }

  void _updatePendingLanguages(String cardId, Set<String> languages) {
    setState(() {
      for (final type in ['wishlist', 'owned']) {
        final key = '$cardId:$type';
        final effectiveLangs = type == 'owned' && languages.length > 1
            ? {languages.where((l) => l != 'ANY').firstOrNull ?? 'ENG'}
            : languages;
        if (_pendingEdits.containsKey(key)) {
          _pendingEdits[key] =
              _pendingEdits[key]!.copyWith(languages: effectiveLangs);
        } else {
          // Card already exists in DB — create a pending edit to update languages
          final isExisting = type == 'wishlist'
              ? _userCardService.isWishlisted(cardId)
              : _userCardService.isOwned(cardId);
          if (isExisting && !_pendingRemovals.contains(key)) {
            final currentLangs = _userCardService.getLanguages(cardId, type);
            if (!_setsEqual(currentLangs, effectiveLangs)) {
              _pendingRemovals.add(key);
              _pendingEdits[key] = PendingCardEdit(
                cardId: cardId,
                type: type,
                languages: effectiveLangs,
              );
            }
          }
        }
      }
    });
  }

  bool _setsEqual(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  bool _mapsEqual(Map<String, Set<String>> a, Map<String, Set<String>> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      final bVal = b[entry.key];
      if (bVal == null || !_setsEqual(entry.value, bVal)) return false;
    }
    return true;
  }

  int _effectiveConditionCount(String cardId) {
    if (_pendingConditions.containsKey(cardId)) {
      return _pendingConditions[cardId]!.length;
    }
    return _userCardService.getTradeConditionCount(cardId);
  }

  bool _isConditionTarget(String cardId) {
    // Check pending conditions first
    for (final conditions in _pendingConditions.values) {
      if (conditions.containsKey(cardId)) return true;
    }
    return _userCardService.isConditionTarget(cardId);
  }

  Future<void> _openConditionsPicker(String cardId) async {
    final card = _allCards.firstWhere((c) => c.id == cardId);
    final currentConditions = _pendingConditions[cardId] ??
        _userCardService.getTradeConditions(cardId);

    final result = await Navigator.push<Map<String, Set<String>>>(
      context,
      MaterialPageRoute(
        builder: (_) => TradeConditionPickerScreen(
          listedCard: card,
          initialSelection: currentConditions,
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      final existing = _userCardService.getTradeConditions(cardId);
      if (_mapsEqual(result, existing)) {
        _pendingConditions.remove(cardId);
      } else {
        _pendingConditions[cardId] = result;
      }
    });
  }

  Future<void> _submitPendingEdits() async {
    setState(() => _isSaving = true);
    final additions = Map<String, PendingCardEdit>.from(_pendingEdits);
    final removals = Set<String>.from(_pendingRemovals);
    final conditions =
        Map<String, Map<String, Set<String>>>.from(_pendingConditions);

    // Track which edits failed so we can keep them in the pending set for retry
    final failedAdditions = <String>{};
    final failedRemovals = <String>{};
    final failedConditions = <String>{};

    // Capture languages to remove BEFORE mutating the cache
    final removalLangs = <String, Set<String>>{};
    for (final key in removals) {
      final lastColon = key.lastIndexOf(':');
      final cardId = key.substring(0, lastColon);
      final type = key.substring(lastColon + 1);
      removalLangs[key] = _userCardService.getLanguages(cardId, type);
    }

    for (final key in removals) {
      final lastColon = key.lastIndexOf(':');
      final cardId = key.substring(0, lastColon);
      final type = key.substring(lastColon + 1);
      for (final lang in removalLangs[key]!) {
        try {
          await _userCardService.removeCard(cardId, type, lang);
        } catch (e) {
          debugPrint('Failed to remove $cardId ($type, $lang): $e');
          failedRemovals.add(key);
        }
      }
    }

    for (final edit in additions.values) {
      for (final lang in edit.languages) {
        try {
          await _userCardService.addCard(edit.cardId, edit.type, lang);
        } catch (e) {
          debugPrint('Failed to add ${edit.cardId} (${edit.type}, $lang): $e');
          failedAdditions.add('${edit.cardId}:${edit.type}');
        }
      }
    }

    // Persist trade conditions
    for (final entry in conditions.entries) {
      try {
        await _userCardService.setTradeConditions(entry.key, entry.value);
      } catch (e) {
        debugPrint('Failed to set conditions for ${entry.key}: $e');
        failedConditions.add(entry.key);
      }
    }

    if (!mounted) return;
    final totalFailed = failedAdditions.length +
        failedRemovals.length +
        failedConditions.length;
    setState(() {
      _isSaving = false;
      // Only clear successful edits. Keep failed ones so the user can retry.
      _pendingEdits.removeWhere((k, _) => !failedAdditions.contains(k));
      _pendingRemovals.removeWhere((k) => !failedRemovals.contains(k));
      _pendingConditions.removeWhere((k, _) => !failedConditions.contains(k));
      if (totalFailed == 0) {
        _currentMode = HomeMode.browse;
      }
    });

    final message = totalFailed == 0
        ? 'Changes saved'
        : '$totalFailed ${totalFailed == 1 ? 'change' : 'changes'} failed — try again';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _toggleEditMode() async {
    if (_currentMode == HomeMode.edit && _hasPendingChanges) {
      final discard = await showAppDialog<bool>(
        context: context,
        title: 'Heads up',
        content: const Text(
            'You have unsaved changes. Do you want to discard them?'),
        cancelText: 'Keep editing',
        primaryText: 'Discard',
        onPrimaryPressed: () => true,
      );
      if (discard != true) return;
    }
    setState(() {
      if (_currentMode == HomeMode.edit) {
        _currentMode = HomeMode.browse;
        _pendingEdits.clear();
        _pendingRemovals.clear();
        _pendingConditions.clear();
      } else {
        _currentMode = HomeMode.edit;
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  Future<bool> _confirmDiscardEdits() async {
    final discard = await showAppDialog<bool>(
      context: context,
      title: 'Heads up',
      content:
          const Text('You have unsaved changes. Do you want to discard them?'),
      cancelText: 'Keep editing',
      primaryText: 'Discard',
      onPrimaryPressed: () => true,
    );
    return discard == true;
  }

  @override
  Widget build(BuildContext context) {
    final hasUnsaved = _currentMode == HomeMode.edit && _hasPendingChanges;
    return PopScope(
      canPop: !hasUnsaved,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !hasUnsaved) return;
        if (await _confirmDiscardEdits() && mounted) {
          setState(() {
            _currentMode = HomeMode.browse;
            _pendingEdits.clear();
            _pendingRemovals.clear();
            _pendingConditions.clear();
          });
        }
      },
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      appBar: HomeAppBar(
        searchController: _searchController,
        onSearchChanged: _onSearchChanged,
        onClearSearch: () {
          _searchController.clear();
          _applyFilters();
        },
        isEditMode: _currentMode == HomeMode.edit,
        onToggleEditMode: _isSaving ? null : _toggleEditMode,
        hasActiveFilters: _hasActiveFilters,
        hasCards: _allCards.isNotEmpty,
        onOpenFilterSheet: _openFilterSheet,
      ),
      body: NotificationListener<ScrollStartNotification>(
        onNotification: (notification) {
          FocusScope.of(context).unfocus();
          return false;
        },
        child: FutureBuilder<List<PocketCard>>(
          future: _cardsFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('Failed to load cards'));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final cards = snapshot.data ?? [];
            if (cards.isEmpty) {
              return const Center(child: Text('No cards found'));
            }

            _populateCards(cards);

            final displayCards = _allCards.isNotEmpty ? _filteredCards : cards;

            return Column(
              children: [
                SortSelector(
                  sortAscending: _sortAscending,
                  showWishlistOnly: _showWishlistOnly,
                  showOwnedOnly: _showOwnedOnly,
                  onSortAscendingChanged: _onSortAscendingChanged,
                  onToggleWishlist: _onToggleWishlist,
                  onToggleOwned: _onToggleOwned,
                ),
                if (_hasActiveFilters)
                  ActiveFilterChips(
                    selectedSets: _selectedSets,
                    selectedRarities: _selectedRarities,
                    selectedPacks: _selectedPacks,
                    selectedCardTypes: _selectedCardTypes,
                    onRemoveFilter: _removeFilter,
                  ),
                if (_isFiltering && displayCards.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${displayCards.length} ${displayCards.length == 1 ? 'result' : 'results'}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshCards,
                    child: displayCards.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.5,
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      PhosphorIcon(
                                          PhosphorIcons.magnifyingGlassMinus(),
                                          size: 64,
                                          color: Colors.white24),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'No cards found',
                                        style: TextStyle(
                                            color: Colors.white38,
                                            fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : CardGrid(
                            cards: displayCards,
                            scrollController: _scrollController,
                            bottomPadding: _currentMode == HomeMode.edit &&
                                    _hasPendingChanges
                                ? 72
                                : 6,
                            bottomOverlay: _currentMode == HomeMode.edit &&
                                    (_hasPendingChanges || _isSaving)
                                ? Positioned(
                                    left: 16,
                                    right: 16,
                                    bottom: 12,
                                    child: ElevatedButton(
                                      onPressed: _isSaving
                                          ? null
                                          : _submitPendingEdits,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.black,
                                        disabledBackgroundColor:
                                            AppColors.primary,
                                        disabledForegroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: _isSaving
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                valueColor:
                                                    AlwaysStoppedAnimation(
                                                        Colors.black),
                                              ),
                                            )
                                          : Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                PhosphorIcon(
                                                    PhosphorIcons.check(),
                                                    size: 18,
                                                    color: Colors.black),
                                                const SizedBox(width: 8),
                                                const Text(
                                                  'Save changes',
                                                  style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  )
                                : null,
                            tileBuilder: (card) => CardTile(
                              card: card,
                              mode: _currentMode,
                              isPendingWishlist: _effectiveWishlist(card.id),
                              isPendingOwned: _effectiveOwned(card.id),
                              isConditionTarget: _isConditionTarget(card.id),
                              pendingLanguages: _effectiveLanguages(card.id),
                              onWishlistToggle: _isSaving
                                  ? null
                                  : (langs) => _togglePending(
                                      card.id, 'wishlist', langs),
                              onOwnedToggle: _isSaving
                                  ? null
                                  : (langs) =>
                                      _togglePending(card.id, 'owned', langs),
                              onLanguagesChanged:
                                  _isSaving ? null : _updatePendingLanguages,
                              tradeConditionCount:
                                  _effectiveConditionCount(card.id),
                              onConditionsPressed: _isSaving
                                  ? null
                                  : () => _openConditionsPicker(card.id),
                            ),
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
