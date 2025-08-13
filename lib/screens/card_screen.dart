import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import '../utils/card_name_formatter.dart';

class CardScreen extends StatefulWidget {
  final Map<String, dynamic> card;
  CardScreen({super.key, required this.card});

  @override
  State<CardScreen> createState() => _CardScreenState();
}

class _CardScreenState extends State<CardScreen> {
  final List<Tab> cardTabs = const [
    Tab(text: 'Offers'),
    Tab(text: 'Wants'),
  ];
  Color? dominantColor;

  final rarityImages = {
    'Common': 'images/rarities/1-diamond.png',
    'Uncommon': 'images/rarities/2-diamond.png',
    'Rare': 'images/rarities/3-diamond.png',
    'Double Rare': 'images/rarities/4-diamond.png',
    'Secret Rare': 'images/rarities/1-star.png',
  };

  final cardHeight = 150.0;

  @override
  void initState() {
    super.initState();
    _updatePalette();
  }

  Future<void> _updatePalette() async {
    final imageUrl = widget.card['image_url'];
    if (imageUrl != null && imageUrl.toString().isNotEmpty) {
      try {
        final PaletteGenerator paletteGenerator =
            await PaletteGenerator.fromImageProvider(
          NetworkImage(imageUrl),
          maximumColorCount: 10,
        );
        setState(() {
          dominantColor = paletteGenerator.dominantColor?.color ?? Colors.black;
        });
      } catch (e) {
        setState(() {
          dominantColor = Colors.black;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final rarity = card['rarity'] ?? 'Common';
    final rarityImage = rarityImages[rarity] ?? rarityImages['Common'];

    // Build Supabase public URL for set image
    final setName =
        card['set']?.toString().toLowerCase().replaceAll(' ', '_') ?? '';
    final setImageUrl = setName.isNotEmpty
        ? 'https://kreowlhmtwomwmzkegzf.supabase.co/storage/v1/object/public/tcgp-icons/$setName.png'
        : null;
    return DefaultTabController(
      length: cardTabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(card['name'] ?? 'Card Details'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (card['image_url'] != null &&
                      card['image_url'].toString().isNotEmpty)
                    Image.network(
                      card['image_url'],
                      height: cardHeight,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.broken_image, size: 100),
                    ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: SizedBox(
                      height: cardHeight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            formatCardName(card['name']),
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.left,
                          ),
                          Image.asset(
                              rarityImage ?? 'assets/rarities/1-diamond.png',
                              height: 24),
                          if (setImageUrl != null)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: Image.network(
                                setImageUrl,
                                height: 32,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.broken_image, size: 32),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TabBar(tabs: cardTabs),
              Expanded(
                child: TabBarView(
                  children: [
                    Center(
                        child: Text(
                            'Players are offering to trade ${formatCardName(card['name'])} for any of these cards')),
                    Center(child: Text('Players who want this card')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
