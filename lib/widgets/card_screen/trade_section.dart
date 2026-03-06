import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/utils/languages.dart';
import 'package:tcgp_trading_app/widgets/card_screen/card_thumbnail.dart';

PocketCard _placeholder(String id, String name, String rarity) => PocketCard(
    id: id, name: name, rarity: rarity, pack: '', imageUrl: '', type: '');

final _placeholderOffers = [
  (card: _placeholder('a1-001', 'Bulbasaur', '◊'), lang: 'ENG'),
  (card: _placeholder('a1-004', 'Charmander', '◊'), lang: 'JPN'),
  (card: _placeholder('a1-007', 'Squirtle', '◊'), lang: 'ENG'),
  (card: _placeholder('a1-035', 'Clefairy', '◊◊'), lang: 'FRA'),
  (card: _placeholder('a1-025', 'Pikachu', '◊◊◊'), lang: 'DEU'),
  (card: _placeholder('a1a-001', 'Ekans', '◊'), lang: 'ESP'),
  (card: _placeholder('a1a-010', 'Mankey', '◊◊'), lang: 'ENG'),
  (card: _placeholder('a1-130', 'Gyarados', '◊◊◊◊'), lang: 'KOR'),
  (card: _placeholder('a1-094', 'Gengar', '◊◊◊'), lang: 'ITA'),
  (card: _placeholder('a1-006', 'Charizard', '◊◊◊'), lang: 'JPN'),
  (card: _placeholder('a1-009', 'Blastoise', '◊◊◊'), lang: 'POR'),
  (card: _placeholder('a1-003', 'Venusaur', '◊◊◊'), lang: 'CHN'),
];

final _placeholderWants = [
  (card: _placeholder('a1-150', 'Mewtwo', '☆'), lang: 'ENG'),
  (card: _placeholder('a1-143', 'Snorlax', '◊◊'), lang: 'JPN'),
  (card: _placeholder('a1-131', 'Lapras', '◊◊◊◊'), lang: 'FRA'),
  (card: _placeholder('a1-113', 'Chansey', '◊◊'), lang: 'ENG'),
  (card: _placeholder('a1a-015', 'Arcanine', '◊◊◊'), lang: 'DEU'),
  (card: _placeholder('a1-026', 'Raichu', '◊◊◊'), lang: 'ESP'),
  (card: _placeholder('a1-082', 'Magneton', '◊◊'), lang: 'KOR'),
  (card: _placeholder('a1-101', 'Electrode', '◊◊'), lang: 'ENG'),
  (card: _placeholder('a1a-005', 'Voltorb', '◊'), lang: 'ITA'),
];

class TradeSection extends StatefulWidget {
  final PocketCard card;

  const TradeSection({super.key, required this.card});

  @override
  State<TradeSection> createState() => _TradeSectionState();
}

class _TradeSectionState extends State<TradeSection>
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(6, 10, 6, 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E24),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: Colors.white38),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
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
                      color:
                          isSelected ? const Color(0xFF02F8AE) : Colors.white70,
                      fontSize: 12,
                    ),
                    backgroundColor: const Color(0xFF1E1E24),
                    side: BorderSide(
                      color:
                          isSelected ? const Color(0xFF02F8AE) : Colors.white24,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 24),
          child: LayoutBuilder(
            builder: (context, constraints) {
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
                itemBuilder: (context, i) => CardThumbnail(
                  card: activeCards[i].card,
                  lang: activeCards[i].lang,
                ),
              );
            },
          ),
        ),
      ],
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
