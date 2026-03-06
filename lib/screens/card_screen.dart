import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/models/card.dart';

// Placeholder trade data
final _placeholderOffers = [
  {
    'username': 'AshKetchum99',
    'cards': [
      PocketCard(
          set: 'A1', number: 1, rarity: 'C', name: 'Bulbasaur', packs: []),
      PocketCard(
          set: 'A1', number: 4, rarity: 'C', name: 'Charmander', packs: []),
      PocketCard(
          set: 'A1', number: 7, rarity: 'C', name: 'Squirtle', packs: []),
    ],
  },
  {
    'username': 'MistyWaterflower',
    'cards': [
      PocketCard(
          set: 'A1', number: 35, rarity: 'U', name: 'Clefairy', packs: []),
      PocketCard(
          set: 'A1', number: 25, rarity: 'R', name: 'Pikachu', packs: []),
    ],
  },
  {
    'username': 'BrockPewter',
    'cards': [
      PocketCard(set: 'A1a', number: 1, rarity: 'C', name: 'Ekans', packs: []),
      PocketCard(
          set: 'A1a', number: 10, rarity: 'U', name: 'Mankey', packs: []),
      PocketCard(
          set: 'A1', number: 130, rarity: 'RR', name: 'Gyarados', packs: []),
      PocketCard(set: 'A1', number: 94, rarity: 'R', name: 'Gengar', packs: []),
    ],
  },
  {
    'username': 'TrainerRed',
    'cards': [
      PocketCard(
          set: 'A1', number: 6, rarity: 'R', name: 'Charizard', packs: []),
      PocketCard(
          set: 'A1', number: 9, rarity: 'R', name: 'Blastoise', packs: []),
      PocketCard(
          set: 'A1', number: 3, rarity: 'R', name: 'Venusaur', packs: []),
    ],
  },
];

final _placeholderWants = [
  {
    'username': 'GaryOak',
    'cards': [
      PocketCard(
          set: 'A1', number: 150, rarity: 'SR', name: 'Mewtwo', packs: []),
      PocketCard(
          set: 'A1', number: 143, rarity: 'U', name: 'Snorlax', packs: []),
      PocketCard(
          set: 'A1', number: 131, rarity: 'RR', name: 'Lapras', packs: []),
    ],
  },
  {
    'username': 'NurseJoy',
    'cards': [
      PocketCard(
          set: 'A1', number: 113, rarity: 'U', name: 'Chansey', packs: []),
      PocketCard(
          set: 'A1a', number: 15, rarity: 'R', name: 'Arcanine', packs: []),
    ],
  },
  {
    'username': 'LtSurge',
    'cards': [
      PocketCard(set: 'A1', number: 26, rarity: 'R', name: 'Raichu', packs: []),
      PocketCard(
          set: 'A1', number: 82, rarity: 'U', name: 'Magneton', packs: []),
      PocketCard(
          set: 'A1', number: 101, rarity: 'U', name: 'Electrode', packs: []),
      PocketCard(
          set: 'A1a', number: 5, rarity: 'C', name: 'Voltorb', packs: []),
    ],
  },
];

class CardScreen extends StatefulWidget {
  final PocketCard card;
  const CardScreen({super.key, required this.card});

  @override
  State<CardScreen> createState() => _CardScreenState();
}

const _languages = [
  'English',
  'Japanese',
  'French',
  'Italian',
  'German',
  'Spanish',
  'Portuguese',
  'Chinese',
  'Korean',
];

class _CardScreenState extends State<CardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _activeTab = 0;
  Set<String> _selectedLanguages = {..._languages};

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

    final activeTrades =
        _activeTab == 0 ? _placeholderOffers : _placeholderWants;
    final activeLabel = _activeTab == 0 ? 'wants' : 'can offer';

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
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                splashFactory: NoSplash.splashFactory,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                tabs: const [
                  Tab(height: 36, text: 'Offers'),
                  Tab(height: 36, text: 'Wants')
                ],
              ),
            ),
            // Language filter
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _selectedLanguages.length == _languages.length,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedLanguages = {..._languages};
                          } else {
                            _selectedLanguages.clear();
                          }
                        });
                      },
                      selectedColor: const Color(0xFF1E1E24),
                      checkmarkColor: const Color(0xFF02F8AE),
                      labelStyle: TextStyle(
                        color: _selectedLanguages.length == _languages.length
                            ? const Color(0xFF02F8AE)
                            : Colors.white70,
                        fontSize: 12,
                      ),
                      backgroundColor: const Color(0xFF1E1E24),
                      side: BorderSide(
                        color: _selectedLanguages.length == _languages.length
                            ? const Color(0xFF02F8AE)
                            : Colors.white24,
                      ),
                    ),
                    const SizedBox(width: 6),
                    ..._languages.map((lang) {
                      final isSelected = _selectedLanguages.contains(lang);
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(lang),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedLanguages.add(lang);
                              } else {
                                _selectedLanguages.remove(lang);
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
            ),
            // Info box for the active tab
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(6, 6, 6, 0),
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
                    child: Text(
                      _activeTab == 0
                          ? 'These users have this card and want to trade it. Check if you have any of the cards they\'re looking for.'
                          : 'These users are looking for this card. See what they can offer you in return.',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                  ),
                ],
              ),
            ),
            // Trade entries rendered inline
            ...activeTrades.map((trade) {
              final username = trade['username'] as String;
              final cards = trade['cards'] as List<PocketCard>;
              return _TradeEntry(
                  username: username, cards: cards, label: activeLabel);
            }),
            const SizedBox(height: 24),
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

class _TradeEntry extends StatelessWidget {
  final String username;
  final List<PocketCard> cards;
  final String label;

  const _TradeEntry({
    required this.username,
    required this.cards,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFF02F8AE),
                child: Text(
                  username[0],
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  username,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label == 'wants' ? 'Looking for:' : 'Can offer:',
            style: const TextStyle(fontSize: 12, color: Colors.white54),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cards.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, i) => _CardThumbnail(card: cards[i]),
            ),
          ),
        ],
      ),
    );
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

  const _CardThumbnail({required this.card});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        card.imageUrl,
        height: 100,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const SizedBox(
            width: 42, height: 100, child: Icon(Icons.broken_image, size: 20)),
      ),
    );
  }
}
