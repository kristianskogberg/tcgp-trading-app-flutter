import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/services/card_service.dart';
import 'package:tcgp_trading_app/widgets/home_screen/card_tile.dart';
import 'package:tcgp_trading_app/widgets/home_screen/filter_sheet.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onMenuTap;
  const HomeScreen({super.key, this.onMenuTap});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<PocketCard>> _cardsFuture;

  // All cards from the data source
  List<PocketCard> _allCards = [];
  // Filtered cards to display
  List<PocketCard> _filteredCards = [];

  // Search
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;

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

  @override
  void initState() {
    super.initState();
    _cardsFuture = CardService().getAllCards();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

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
        _filteredCards = List.of(cards);
      });
    });
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCards = _allCards.where((card) {
        // Search filter
        if (query.isNotEmpty && !card.name.toLowerCase().contains(query)) {
          return false;
        }
        // Set filter (OR within category)
        if (_selectedSets.isNotEmpty && !_selectedSets.contains(card.set)) {
          return false;
        }
        // Rarity filter (OR within category)
        if (_selectedRarities.isNotEmpty &&
            !_selectedRarities.contains(card.rarity)) {
          return false;
        }
        // Pack filter (OR within category)
        if (_selectedPacks.isNotEmpty && !_selectedPacks.contains(card.pack)) {
          return false;
        }
        return true;
      }).toList()
        ..sort((a, b) => a.number.compareTo(b.number));
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

  List<Widget> _buildActiveFilterChips() {
    final chips = <Widget>[];
    for (final s in _selectedSets) {
      chips.add(_buildDismissibleChip(s, 'set'));
    }
    for (final r in _selectedRarities) {
      chips.add(_buildDismissibleChip(r, 'rarity'));
    }
    for (final p in _selectedPacks) {
      chips.add(_buildDismissibleChip(p, 'pack'));
    }
    return chips;
  }

  Widget _buildDismissibleChip(String label, String type) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: true,
        onSelected: (_) => _removeFilter(type, label),
        selectedColor: const Color(0xFF02F8AE),
        deleteIcon: const Icon(Icons.close, size: 16),
        onDeleted: () => _removeFilter(type, label),
        deleteIconColor: Colors.white70,
        labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: const Color(0xFF02F8AE)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: widget.onMenuTap != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: widget.onMenuTap,
              )
            : null,
        title: SizedBox(
          height: 40,
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            keyboardType: TextInputType.text,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Search cards...',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 15),
              prefixIcon:
                  const Icon(Icons.search, color: Colors.white38, size: 20),
              suffixIcon: ListenableBuilder(
                listenable: _searchController,
                builder: (context, _) {
                  if (_searchController.text.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white54, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      _applyFilters();
                    },
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
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.tune),
                onPressed: _allCards.isNotEmpty ? _openFilterSheet : null,
              ),
              if (_hasActiveFilters)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: const Color(0xFF02F8AE),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
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

            // Populate _allCards once data arrives
            _populateCards(cards);

            // Use _filteredCards if populated, otherwise show all
            final displayCards = _allCards.isNotEmpty ? _filteredCards : cards;

            return Column(
              children: [
                // Active filter chips row
                if (_hasActiveFilters)
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      children: _buildActiveFilterChips(),
                    ),
                  ),
                // Result count
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
                // Card grid or empty state
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
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            int crossAxisCount =
                                (constraints.maxWidth ~/ 180).clamp(3, 4);
                            return GridView.builder(
                              controller: _scrollController,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                childAspectRatio: 0.7,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              padding: const EdgeInsets.all(6),
                              itemCount: displayCards.length,
                              itemBuilder: (context, index) {
                                return CardTile(card: displayCards[index]);
                              },
                            );
                          },
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
