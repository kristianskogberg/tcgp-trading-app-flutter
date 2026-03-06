import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/screens/card_screen.dart';
import 'package:tcgp_trading_app/services/card_service.dart';

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
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
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
        packs.addAll(card.packs);
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
        if (_selectedPacks.isNotEmpty &&
            !card.packs.any((p) => _selectedPacks.contains(p))) {
          return false;
        }
        return true;
      }).toList()
        ..sort((a, b) => a.number.compareTo(b.number));
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
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
    // Draft copies
    var draftSets = Set<String>.from(_selectedSets);
    var draftRarities = Set<String>.from(_selectedRarities);
    var draftPacks = Set<String>.from(_selectedPacks);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setSheetState) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF141418),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      // Handle bar
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 8),
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // Title
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Filters',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      // Filter sections
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          children: [
                            _buildFilterSection(
                              'Set',
                              _availableSets,
                              draftSets,
                              (val) => setSheetState(() {
                                draftSets.contains(val)
                                    ? draftSets.remove(val)
                                    : draftSets.add(val);
                              }),
                            ),
                            const SizedBox(height: 16),
                            _buildFilterSection(
                              'Rarity',
                              _availableRarities,
                              draftRarities,
                              (val) => setSheetState(() {
                                draftRarities.contains(val)
                                    ? draftRarities.remove(val)
                                    : draftRarities.add(val);
                              }),
                            ),
                            const SizedBox(height: 16),
                            _buildFilterSection(
                              'Packs',
                              _availablePacks,
                              draftPacks,
                              (val) => setSheetState(() {
                                draftPacks.contains(val)
                                    ? draftPacks.remove(val)
                                    : draftPacks.add(val);
                              }),
                            ),
                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
                      // Bottom buttons
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        decoration: const BoxDecoration(
                          color: Color(0xFF141418),
                          border: Border(
                            top: BorderSide(color: Colors.white12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setSheetState(() {
                                    draftSets.clear();
                                    draftRarities.clear();
                                    draftPacks.clear();
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                  side: const BorderSide(color: Colors.white24),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: const Text('Clear All'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedSets = draftSets;
                                    _selectedRarities = draftRarities;
                                    _selectedPacks = draftPacks;
                                  });
                                  _applyFilters();
                                  Navigator.pop(context);
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF02F8AE),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: const Text('Apply'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFilterSection(
    String title,
    List<String> options,
    Set<String> selected,
    void Function(String) onToggle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selected.contains(option);
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (_) => onToggle(option),
              selectedColor: const Color(0xFF02F8AE),
              checkmarkColor: Colors.white,
              backgroundColor: const Color(0xFF1E1E24),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF02F8AE) : Colors.white24,
                ),
              ),
            );
          }).toList(),
        ),
      ],
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
      body: FutureBuilder<List<PocketCard>>(
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                              return _CardTile(card: displayCards[index]);
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  final PocketCard card;
  const _CardTile({required this.card});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            opaque: false,
            transitionDuration: const Duration(milliseconds: 300),
            reverseTransitionDuration: const Duration(milliseconds: 300),
            pageBuilder: (context, animation, secondaryAnimation) =>
                CardScreen(card: card),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          ),
        );
      },
      child: Hero(
        tag: 'card-hero-${card.id}',
        createRectTween: (begin, end) => RectTween(begin: begin, end: end),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            card.imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.broken_image, color: Colors.white24);
            },
          ),
        ),
      ),
    );
  }
}
