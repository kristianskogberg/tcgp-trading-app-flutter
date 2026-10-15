import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:tcgp_trading_app/auth/profile_service.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/models/home_mode.dart';
import 'package:tcgp_trading_app/services/card_service.dart';
import 'package:tcgp_trading_app/collection/collection.dart';
import 'package:tcgp_trading_app/collection/collection_draft.dart';
import 'package:tcgp_trading_app/collection/collection_store.dart';
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
  final _collectionStore = CollectionStore();

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
  bool _showListingsOnly = false;

  // Edit mode: one Collection draft for the whole session, null otherwise.
  CollectionDraft? _draft;

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

  bool get _hasUnsavedChanges => _draft?.hasChanges ?? false;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _cardsFuture = CardService().getAllCards();
    _collectionStore.addListener(_onCollectionChanged);
    _collectionStore
        .load()
        .catchError((e) => debugPrint('Failed to load user cards: $e'));
  }

  @override
  void dispose() {
    _collectionStore.removeListener(_onCollectionChanged);
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
      CardService().precacheCardImages(cards: _filteredCards);
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
        if (_showListingsOnly && !_effectiveListing(card.id)) return false;
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
      if (_showWishlistOnly) _showListingsOnly = false;
    });
    _applyFilters();
  }

  void _onToggleListings() {
    setState(() {
      _showListingsOnly = !_showListingsOnly;
      if (_showListingsOnly) _showWishlistOnly = false;
    });
    _applyFilters();
  }

  // ---------------------------------------------------------------------------
  // Edit mode logic
  // ---------------------------------------------------------------------------

  /// Keeps an edit session on top of the latest saved collection, for
  /// example when it finishes loading after edit mode was entered.
  void _onCollectionChanged() {
    if (!mounted) return;
    setState(() => _draft = _draft?.rebasedOn(_collectionStore.collection));
  }

  CardState _stateOf(String cardId) =>
      _draft?.stateOf(cardId) ?? _collectionStore.collection.stateOf(cardId);

  bool _effectiveWishlist(String cardId) => _stateOf(cardId) is Wishlisted;

  bool _effectiveListing(String cardId) => _stateOf(cardId) is Listed;

  Set<String> _effectiveLanguages(String cardId) {
    final languages = _stateOf(cardId).languages;
    if (languages.isNotEmpty) return languages;
    return {_draft?.preferredLanguage ?? fallbackPreferredLanguage};
  }

  bool _isConditionTarget(String cardId) =>
      _draft?.isTradeConditionTarget(cardId) ??
      _collectionStore.collection.isTradeConditionTarget(cardId);

  /// Applies [intent] to the edit session's draft.
  void _edit(CollectionDraft Function(CollectionDraft draft) intent) {
    final draft = _draft;
    if (draft == null || _isSaving) return;
    setState(() => _draft = intent(draft));
  }

  Future<void> _openConditionsPicker(String cardId) async {
    final card = _allCards.firstWhere((c) => c.id == cardId);
    final result = await Navigator.push<List<TradeCondition>>(
      context,
      MaterialPageRoute(
        builder: (_) => TradeConditionPickerScreen(
          listedCard: card,
          initialConditions: _stateOf(cardId).tradeConditions,
        ),
      ),
    );

    if (result == null || !mounted) return;
    _edit((d) => d.setTradeConditions(cardId, result));
  }

  /// Saves the whole session in one atomic call. On failure nothing is
  /// saved and the session stays open with every change.
  Future<void> _saveDraft() async {
    final draft = _draft;
    if (draft == null || !draft.hasChanges) return;
    setState(() => _isSaving = true);

    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    try {
      await _collectionStore.commit(draft.changes);
    } catch (e) {
      debugPrint('Failed to save collection changes: $e');
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(const SnackBar(
        content: Text(
            "Couldn't save your changes. Check your connection and try again."),
      ));
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _exitEditMode();
    });
    messenger.showSnackBar(const SnackBar(content: Text('Changes saved')));
  }

  /// Ends the edit session, dropping its draft. Call inside setState.
  void _exitEditMode() {
    _currentMode = HomeMode.browse;
    _draft = null;
  }

  Future<void> _toggleEditMode() async {
    if (_currentMode == HomeMode.edit) {
      if (_hasUnsavedChanges && !await _confirmDiscardEdits()) return;
      setState(_exitEditMode);
      return;
    }
    final modeBefore = _currentMode;
    final preferredLanguage = await ProfileService().getPreferredLanguage();
    // The user moved on (or tapped twice) while it loaded.
    if (!mounted || _currentMode != modeBefore) return;
    setState(() {
      _currentMode = HomeMode.edit;
      _draft = CollectionDraft(
        _collectionStore.collection,
        preferredLanguage: preferredLanguage,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  String get _saveLabel {
    final count = _draft?.changes.length ?? 0;
    return 'Save $count ${count == 1 ? 'change' : 'changes'}';
  }

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
    final hasUnsaved = _currentMode == HomeMode.edit && _hasUnsavedChanges;
    return PopScope(
      canPop: !hasUnsaved,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !hasUnsaved) return;
        if (await _confirmDiscardEdits() && mounted) {
          setState(_exitEditMode);
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
                  showListingsOnly: _showListingsOnly,
                  onSortAscendingChanged: _onSortAscendingChanged,
                  onToggleWishlist: _onToggleWishlist,
                  onToggleListings: _onToggleListings,
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
                                    _hasUnsavedChanges
                                ? 72
                                : 6,
                            bottomOverlay: _currentMode == HomeMode.edit &&
                                    (_hasUnsavedChanges || _isSaving)
                                ? Positioned(
                                    left: 16,
                                    right: 16,
                                    bottom: 12,
                                    child: ElevatedButton(
                                      onPressed: _isSaving
                                          ? null
                                          : _saveDraft,
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
                                                Text(
                                                  _saveLabel,
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
                              isPendingListing: _effectiveListing(card.id),
                              isConditionTarget: _isConditionTarget(card.id),
                              pendingLanguages: _effectiveLanguages(card.id),
                              languageChoices:
                                  _draft?.languageChoicesFor(card.id),
                              onWishlistToggle: _isSaving
                                  ? null
                                  : () => _edit(
                                      (d) => d.toggleWishlist(card.id)),
                              onListingToggle: _isSaving
                                  ? null
                                  : () =>
                                      _edit((d) => d.toggleListing(card.id)),
                              onLanguagesChanged: _isSaving
                                  ? null
                                  : (cardId, languages) => _edit(
                                      (d) => d.setLanguages(cardId, languages)),
                              tradeConditionCount:
                                  _stateOf(card.id).tradeConditions.length,
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
