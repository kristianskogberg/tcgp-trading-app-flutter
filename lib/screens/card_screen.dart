import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:tcgp_trading_app/models/card.dart';

class CardScreen extends StatefulWidget {
  final PocketCard card;
  const CardScreen({super.key, required this.card});

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
    'C': 'images/rarities/1-diamond.png',
    'U': 'images/rarities/2-diamond.png',
    'R': 'images/rarities/3-diamond.png',
    'RR': 'images/rarities/4-diamond.png',
    'SR': 'images/rarities/1-star.png',
    'AR': 'images/rarities/1-star.png',
    'SAR': 'images/rarities/1-star.png',
    'IM': 'images/rarities/1-star.png',
    'UR': 'images/rarities/1-star.png',
  };

  final rarityLabels = {
    'C': 'Common',
    'U': 'Uncommon',
    'R': 'Rare',
    'RR': 'Double Rare',
    'SR': 'Secret Rare',
    'AR': 'Art Rare',
    'SAR': 'Special Art Rare',
    'IM': 'Immersive',
    'UR': 'Ultra Rare',
  };

  final cardHeight = 400.0;

  @override
  void initState() {
    super.initState();
    _updatePalette();
  }

  Future<void> _updatePalette() async {
    final imageUrl = widget.card.imageUrl;
    try {
      final PaletteGenerator paletteGenerator =
          await PaletteGenerator.fromImageProvider(
        NetworkImage(imageUrl),
        maximumColorCount: 10,
      );
      if (!mounted) return;
      setState(() {
        dominantColor = paletteGenerator.dominantColor?.color ?? Colors.black;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        dominantColor = Colors.black;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final rarityImage = rarityImages[card.rarity] ?? 'images/rarities/1-diamond.png';

    final setName = card.set.toLowerCase().replaceAll(' ', '_');
    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    final setImageUrl = setName.isNotEmpty && supabaseUrl.isNotEmpty
        ? '$supabaseUrl/storage/v1/object/public/tcgp_icons/$setName.webp'
        : null;

    return DefaultTabController(
      length: cardTabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(card.name),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Image.network(
                card.imageUrl,
                height: cardHeight,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.broken_image, size: 100),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _onWantPressed,
                      child: const Text('I want this card'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _onCanTradePressed,
                      child: const Text('I can trade this card'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Image.asset(
                          rarityImage,
                          height: 24,
                        ),
                        if (setImageUrl != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
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
                ],
              ),
            ],
          ),
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
