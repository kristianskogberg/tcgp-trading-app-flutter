import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:tcgp_trading_app/config/app_colors.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/services/card_service.dart';
import 'package:tcgp_trading_app/utils/rarity_utils.dart';
import 'package:tcgp_trading_app/utils/set_image_url.dart';
import 'package:tcgp_trading_app/widgets/shared/app_dialog.dart';
import 'package:tcgp_trading_app/widgets/shared/card_language_button.dart';
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
    }).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
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
      if (query.isEmpty) {
        _filteredCards = List.from(_allCards);
      } else {
        _filteredCards = _allCards
            .where((card) => card.name.toLowerCase().contains(query))
            .toList();
      }
    });
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
          if (_selectedScrollController.hasClients) {
            _selectedScrollController.animateTo(
              _selectedScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
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
    // Group cards by set
    final grouped = <String, List<PocketCard>>{};
    for (final card in _filteredCards) {
      grouped.putIfAbsent(card.set, () => []).add(card);
    }
    final setOrder = grouped.keys.toList()..sort();

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
                    child: _selected.isEmpty
                        ? const _DashedPlaceholderCard()
                        : ListView.separated(
                            controller: _selectedScrollController,
                            scrollDirection: Axis.horizontal,
                            itemCount: _selected.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
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
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: PhosphorIcon(
                                            PhosphorIcons.x(
                                                PhosphorIconsStyle.bold),
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        child: CardLanguageButton(
                                          languages: langs,
                                          color: AppColors.primary,
                                          rounded: false,
                                          onTap: () =>
                                              _showLanguagePicker(cardId),
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

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 4),
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                keyboardType: TextInputType.text,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search cards...',
                  hintStyle:
                      const TextStyle(color: Colors.white38, fontSize: 15),
                  prefixIcon: PhosphorIcon(PhosphorIcons.magnifyingGlass(),
                      color: Colors.white38, size: 20),
                  suffixIcon: ListenableBuilder(
                    listenable: _searchController,
                    builder: (context, _) {
                      if (_searchController.text.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return IconButton(
                        icon: PhosphorIcon(PhosphorIcons.x(),
                            color: Colors.white54, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _applyFilter();
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
          ),
          // Card grid
          Expanded(
            child: _filteredCards.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PhosphorIcon(PhosphorIcons.magnifyingGlassMinus(),
                            size: 64, color: Colors.white24),
                        const SizedBox(height: 12),
                        const Text(
                          'No cards found',
                          style: TextStyle(color: Colors.white38, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount =
                          (constraints.maxWidth ~/ 180).clamp(3, 4);
                      final gridDelegate =
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 367 / 512,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      );

                      return CustomScrollView(
                        controller: _scrollController,
                        slivers: [
                          for (int i = 0; i < setOrder.length; i++) ...[
                            SliverToBoxAdapter(
                              child: _SetHeader(
                                setId: setOrder[i],
                                isFirst: i == 0,
                              ),
                            ),
                            SliverPadding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              sliver: SliverGrid(
                                gridDelegate: gridDelegate,
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final card = grouped[setOrder[i]]![index];
                                    final isSelected =
                                        _selected.containsKey(card.id);
                                    return _PickerCardTile(
                                      card: card,
                                      isSelected: isSelected,
                                      language: _selected[card.id],
                                      onTap: () => _toggleCard(card.id),
                                      onLanguageTap: isSelected
                                          ? () => _showLanguagePicker(card.id)
                                          : null,
                                    );
                                  },
                                  childCount: grouped[setOrder[i]]!.length,
                                ),
                              ),
                            ),
                          ],
                          const SliverPadding(
                              padding: EdgeInsets.only(bottom: 16)),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PickerCardTile extends StatelessWidget {
  final PocketCard card;
  final bool isSelected;
  final Set<String>? language;
  final VoidCallback onTap;
  final VoidCallback? onLanguageTap;

  const _PickerCardTile({
    required this.card,
    required this.isSelected,
    this.language,
    required this.onTap,
    this.onLanguageTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: OptimizedCardImage(
                imageUrl: card.imageUrl,
                isThumbnail: true,
                fit: BoxFit.cover,
              ),
            ),
          ),
          if (isSelected) ...[
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.black.withAlpha(100),
                  border: Border.all(color: AppColors.primary, width: 3),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: PhosphorIcon(
                  PhosphorIcons.check(PhosphorIconsStyle.bold),
                  size: 12,
                  color: Colors.black,
                ),
              ),
            ),
            Positioned(
              bottom: 3,
              left: 3,
              right: 3,
              child: CardLanguageButton(
                languages: language ?? {'ANY'},
                color: AppColors.primary,
                onTap: onLanguageTap,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SetHeader extends StatelessWidget {
  final String setId;
  final bool isFirst;

  const _SetHeader({required this.setId, required this.isFirst});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: isFirst ? 6 : 16,
        bottom: 8,
        left: 6,
        right: 6,
      ),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: CachedNetworkImage(
              imageUrl: setImageUrl(setId),
              height: 24,
              fit: BoxFit.contain,
              errorWidget: (context, url, error) => Text(
                setId,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const Expanded(child: Divider()),
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
