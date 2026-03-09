import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/models/home_mode.dart';
import 'package:tcgp_trading_app/models/pending_card_edit.dart';
import 'package:tcgp_trading_app/services/card_service.dart';
import 'package:tcgp_trading_app/services/user_card_service.dart';
import 'package:tcgp_trading_app/widgets/home_screen/active_filter_chips.dart';
import 'package:tcgp_trading_app/widgets/home_screen/card_grid.dart';
import 'package:tcgp_trading_app/widgets/home_screen/filter_sheet.dart';
import 'package:tcgp_trading_app/widgets/home_screen/home_app_bar.dart';
import 'package:tcgp_trading_app/widgets/home_screen/sort_selector.dart';
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
  String _sortBy = 'set'; // 'set', 'wishlist', 'owned'

  // Pending edits for edit mode
  final Map<String, PendingCardEdit> _pendingEdits = {};
  final Set<String> _pendingRemovals = {};

  // Available filter options (extracted from data)
  List<String> _availableSets = [];
  List<String> _availableRarities = [];
  List<String> _availablePacks = [];

  // Active filters
  Set<String> _selectedSets = {};
  Set<String> _selectedRarities = {};
  Set<String> _selectedPacks = {};

  bool get _hasActiveFilters =>
      _selectedSets.isNotEmpty ||
      _selectedRarities.isNotEmpty ||
      _selectedPacks.isNotEmpty;

  bool get _isFiltering =>
      _hasActiveFilters || _searchController.text.isNotEmpty;

  bool get _hasPendingChanges =>
      _pendingEdits.isNotEmpty || _pendingRemovals.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _cardsFuture = CardService().getAllCards();
    _userCardService.loadMyCards();
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
      final sets = <String>{};
      final rarities = <String>{};
      final packs = <String>{};
      for (final card in cards) {
        sets.add(card.set);
        rarities.add(card.rarity);
        if (card.pack.isNotEmpty) packs.add(card.pack);
      }
      setState(() {
        _allCards = cards;
        _availableSets = sets.toList()..sort();
        _availableRarities = rarities.toList()..sort();
        _availablePacks = packs.toList()..sort();
        _filteredCards = List.of(cards)..sort((a, b) => a.id.compareTo(b.id));
      });
    });
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
        return true;
      }).toList()
        ..sort((a, b) {
          if (_sortBy == 'wishlist') {
            final aW = _effectiveWishlist(a.id);
            final bW = _effectiveWishlist(b.id);
            if (aW && !bW) return -1;
            if (!aW && bW) return 1;
          } else if (_sortBy == 'owned') {
            final aO = _effectiveOwned(a.id);
            final bO = _effectiveOwned(b.id);
            if (aO && !bO) return -1;
            if (!aO && bO) return 1;
          }
          return a.id.compareTo(b.id);
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
      selectedSets: _selectedSets,
      selectedRarities: _selectedRarities,
      selectedPacks: _selectedPacks,
      onApply: (sets, rarities, packs) {
        setState(() {
          _selectedSets = sets;
          _selectedRarities = rarities;
          _selectedPacks = packs;
        });
        _applyFilters();
      },
    );
  }

  void _onSortChanged(String sort) {
    setState(() => _sortBy = sort);
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
        if (_pendingEdits.containsKey(key)) {
          _pendingEdits[key] =
              _pendingEdits[key]!.copyWith(languages: languages);
        } else {
          // Card already exists in DB — create a pending edit to update languages
          final isExisting = type == 'wishlist'
              ? _userCardService.isWishlisted(cardId)
              : _userCardService.isOwned(cardId);
          if (isExisting && !_pendingRemovals.contains(key)) {
            final currentLangs = _userCardService.getLanguages(cardId, type);
            if (!_setsEqual(currentLangs, languages)) {
              _pendingRemovals.add(key);
              _pendingEdits[key] = PendingCardEdit(
                cardId: cardId,
                type: type,
                languages: languages,
              );
            }
          }
        }
      }
    });
  }

  bool _setsEqual(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  Future<void> _submitPendingEdits() async {
    final additions = Map<String, PendingCardEdit>.from(_pendingEdits);
    final removals = Set<String>.from(_pendingRemovals);
    int successCount = 0;
    int failCount = 0;

    // Update in-memory cache immediately so UI reflects changes
    _userCardService.applyBulkEditsToCache(
      additions: additions,
      removals: removals,
    );

    for (final key in removals) {
      final lastColon = key.lastIndexOf(':');
      final cardId = key.substring(0, lastColon);
      final type = key.substring(lastColon + 1);
      final existingLangs = _userCardService.getLanguages(cardId, type);
      for (final lang in existingLangs) {
        try {
          await _userCardService.removeCard(cardId, type, lang);
          successCount++;
        } catch (e) {
          failCount++;
        }
      }
    }

    for (final edit in additions.values) {
      for (final lang in edit.languages) {
        try {
          await _userCardService.addCard(edit.cardId, edit.type, lang);
          successCount++;
        } catch (e) {
          failCount++;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _pendingEdits.clear();
      _pendingRemovals.clear();
      _currentMode = HomeMode.browse;
    });

    final message =
        failCount == 0 ? 'Changes saved' : 'Some changes failed to save';

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
      } else {
        _currentMode = HomeMode.edit;
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HomeAppBar(
        searchController: _searchController,
        onSearchChanged: _onSearchChanged,
        onClearSearch: () {
          _searchController.clear();
          _applyFilters();
        },
        isEditMode: _currentMode == HomeMode.edit,
        onToggleEditMode: _toggleEditMode,
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
                  currentSort: _sortBy,
                  onSortChanged: _onSortChanged,
                ),
                if (_hasActiveFilters)
                  ActiveFilterChips(
                    selectedSets: _selectedSets,
                    selectedRarities: _selectedRarities,
                    selectedPacks: _selectedPacks,
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
                  child: displayCards.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off,
                                  size: 64, color: Colors.white24),
                              const SizedBox(height: 12),
                              const Text(
                                'No cards match',
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : CardGrid(
                          cards: displayCards,
                          scrollController: _scrollController,
                          mode: _currentMode,
                          hasPendingChanges: _hasPendingChanges,
                          pendingCount: _pendingEdits.length +
                              _pendingRemovals
                                  .where(
                                      (key) => !_pendingEdits.containsKey(key))
                                  .length,
                          effectiveWishlist: _effectiveWishlist,
                          effectiveOwned: _effectiveOwned,
                          effectiveLanguages: _effectiveLanguages,
                          onWishlistToggle: (cardId, langs) =>
                              _togglePending(cardId, 'wishlist', langs),
                          onOwnedToggle: (cardId, langs) =>
                              _togglePending(cardId, 'owned', langs),
                          onLanguagesChanged: _updatePendingLanguages,
                          onSubmit: _submitPendingEdits,
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
