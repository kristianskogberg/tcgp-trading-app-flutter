import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/utils/languages.dart';

// Placeholder trade data (card + language code)
final _placeholderOffers = [
  (
    card: PocketCard(
        set: 'A1', number: 1, rarity: 'C', name: 'Bulbasaur', packs: []),
    lang: 'ENG'
  ),
  (
    card: PocketCard(
        set: 'A1', number: 4, rarity: 'C', name: 'Charmander', packs: []),
    lang: 'JPN'
  ),
  (
    card: PocketCard(
        set: 'A1', number: 7, rarity: 'C', name: 'Squirtle', packs: []),
    lang: 'ENG'
  ),
  (
    card: PocketCard(
        set: 'A1', number: 35, rarity: 'U', name: 'Clefairy', packs: []),
    lang: 'FRA'
  ),
  (
    card: PocketCard(
        set: 'A1', number: 25, rarity: 'R', name: 'Pikachu', packs: []),
    lang: 'DEU'
  ),
  (
    card: PocketCard(
        set: 'A1a', number: 1, rarity: 'C', name: 'Ekans', packs: []),
    lang: 'ESP'
  ),
  (
    card: PocketCard(
        set: 'A1a', number: 10, rarity: 'U', name: 'Mankey', packs: []),
    lang: 'ENG'
  ),
  (
    card: PocketCard(
        set: 'A1', number: 130, rarity: 'RR', name: 'Gyarados', packs: []),
    lang: 'KOR'
  ),
  (
    card: PocketCard(
        set: 'A1', number: 94, rarity: 'R', name: 'Gengar', packs: []),
    lang: 'ITA'
  ),
  (
    card: PocketCard(
        set: 'A1', number: 6, rarity: 'R', name: 'Charizard', packs: []),
    lang: 'JPN'
  ),
  (
    card: PocketCard(
        set: 'A1', number: 9, rarity: 'R', name: 'Blastoise', packs: []),
    lang: 'POR'
  ),
  (
    card: PocketCard(
        set: 'A1', number: 3, rarity: 'R', name: 'Venusaur', packs: []),
    lang: 'CHN'
  ),
];

final _placeholderWants = [
  (
    card: PocketCard(
        set: 'A1', number: 150, rarity: 'SR', name: 'Mewtwo', packs: []),
    lang: 'ENG'
  ),
  (
    card: PocketCard(
        set: 'A1', number: 143, rarity: 'U', name: 'Snorlax', packs: []),
    lang: 'JPN'
  ),
  (
    card: PocketCard(
        set: 'A1', number: 131, rarity: 'RR', name: 'Lapras', packs: []),
    lang: 'FRA'
  ),
  (
    card: PocketCard(
        set: 'A1', number: 113, rarity: 'U', name: 'Chansey', packs: []),
    lang: 'ENG'
  ),
  (
    card: PocketCard(
        set: 'A1a', number: 15, rarity: 'R', name: 'Arcanine', packs: []),
    lang: 'DEU'
  ),
  (
    card: PocketCard(
        set: 'A1', number: 26, rarity: 'R', name: 'Raichu', packs: []),
    lang: 'ESP'
  ),
  (
    card: PocketCard(
        set: 'A1', number: 82, rarity: 'U', name: 'Magneton', packs: []),
    lang: 'KOR'
  ),
  (
    card: PocketCard(
        set: 'A1', number: 101, rarity: 'U', name: 'Electrode', packs: []),
    lang: 'ENG'
  ),
  (
    card: PocketCard(
        set: 'A1a', number: 5, rarity: 'C', name: 'Voltorb', packs: []),
    lang: 'ITA'
  ),
];

class CardScreen extends StatefulWidget {
  final PocketCard card;
  const CardScreen({super.key, required this.card});

  @override
  State<CardScreen> createState() => _CardScreenState();
}

class _CardScreenState extends State<CardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _activeTab = 0;
  Set<String> _selectedLanguages = {...languages.keys};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _activeTab = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;

    final activeCards =
        _activeTab == 0 ? _placeholderOffers : _placeholderWants;

    return Scaffold(
      appBar: AppBar(
        title: Text(card.name),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: 'card-hero-${card.id}',
                    createRectTween: (begin, end) =>
                        RectTween(begin: begin, end: end),
                    child: Image.network(
                      card.imageUrl,
                      height: 220,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.broken_image, size: 100),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoRow(
                          label: 'Set',
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.network(
                                'https://nsqcktpyuedsjcjkllll.supabase.co/storage/v1/object/public/tcgp_icons/${card.set.toLowerCase()}.webp',
                                height: 24,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _InfoRow(
                          label: 'Rarity',
                          child: Text(card.rarity,
                              style: const TextStyle(color: Colors.white)),
                        ),
                        const SizedBox(height: 12),
                        _InfoRow(
                          label: 'Pack',
                          child: Text(
                              card.packs.isNotEmpty
                                  ? card.packs.join(', ')
                                  : '—',
                              style: const TextStyle(color: Colors.white)),
                        ),
                        const SizedBox(height: 12),
                        const _InfoRow(
                          label: 'Trade cost',
                          child:
                              Text('—', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _onWantPressed,
                      icon: const Icon(Icons.favorite_outline, size: 18),
                      label: const Text('I want this card'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _onCanTradePressed,
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('I have this card'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E24),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: const Color(0xFF02F8AE),
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerHeight: 0,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                ),
                splashFactory: NoSplash.splashFactory,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                tabs: const [
                  Tab(height: 36, text: 'Get this card'),
                  Tab(height: 36, text: 'Trade this card')
                ],
              ),
            ),
            // Info box for the active tab
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(6, 10, 6, 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E24),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: Colors.white38),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white54),
                        children: _activeTab == 0
                            ? [
                                const TextSpan(text: 'If you want '),
                                TextSpan(
                                  text: card.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white70),
                                ),
                                const TextSpan(
                                    text:
                                        ' and you are willing to trade for it, these are cards you could offer in return.'),
                              ]
                            : [
                                const TextSpan(text: 'If you own '),
                                TextSpan(
                                  text: card.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white70),
                                ),
                                const TextSpan(
                                    text:
                                        ' and you are willing to trade it, these are cards you could ask for in a trade.'),
                              ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Language filter
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: _selectedLanguages.length == languages.length,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedLanguages = {...languages.keys};
                        } else {
                          _selectedLanguages.clear();
                        }
                      });
                    },
                    selectedColor: const Color(0xFF1E1E24),
                    checkmarkColor: const Color(0xFF02F8AE),
                    labelStyle: TextStyle(
                      color: _selectedLanguages.length == languages.length
                          ? const Color(0xFF02F8AE)
                          : Colors.white70,
                      fontSize: 12,
                    ),
                    backgroundColor: const Color(0xFF1E1E24),
                    side: BorderSide(
                      color: _selectedLanguages.length == languages.length
                          ? const Color(0xFF02F8AE)
                          : Colors.white24,
                    ),
                  ),
                  const SizedBox(width: 6),
                  ...languages.entries.map((entry) {
                    final isSelected = _selectedLanguages.contains(entry.key);
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(entry.value),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedLanguages.add(entry.key);
                            } else {
                              _selectedLanguages.remove(entry.key);
                            }
                          });
                        },
                        selectedColor: const Color(0xFF1E1E24),
                        checkmarkColor: const Color(0xFF02F8AE),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? const Color(0xFF02F8AE)
                              : Colors.white70,
                          fontSize: 12,
                        ),
                        backgroundColor: const Color(0xFF1E1E24),
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFF02F8AE)
                              : Colors.white24,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            // Card grid
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // 3 columns on small screens, 4 on medium, 5 on wide
                  final width = constraints.maxWidth;
                  final crossAxisCount = width < 300
                      ? 3
                      : width < 400
                          ? 4
                          : 5;
                  const spacing = 8.0;
                  final itemWidth =
                      (width - spacing * (crossAxisCount - 1)) / crossAxisCount;
                  final itemHeight = itemWidth * 1.4;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                      childAspectRatio: itemWidth / itemHeight,
                    ),
                    itemCount: activeCards.length,
                    itemBuilder: (context, i) => _CardThumbnail(
                      card: activeCards[i].card,
                      lang: activeCards[i].lang,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onWantPressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Marked as want')),
    );
    debugPrint('User wants card: ${widget.card.id}');
  }

  void _onCanTradePressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Marked as can trade')),
    );
    debugPrint('User can trade card: ${widget.card.id}');
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _InfoRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.white54)),
        const SizedBox(height: 2),
        child,
      ],
    );
  }
}

class _CardThumbnail extends StatelessWidget {
  final PocketCard card;
  final String lang;

  const _CardThumbnail({required this.card, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              card.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const Center(child: Icon(Icons.broken_image, size: 20)),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(0),
            ),
            child: Text(
              lang,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w400),
            ),
          ),
        ),
      ],
    );
  }
}
