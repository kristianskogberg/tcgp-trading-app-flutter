import 'dart:async';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/screens/card_screen.dart';
import 'package:tcgp_trading_app/services/card_service.dart';

/// Global cache so colors survive rebuilds and scrolling.
final Map<String, Color> _dominantColorCache = {};

/// Completer map to avoid duplicate extractions for the same card.
final Map<String, Completer<Color>> _pendingExtractions = {};

Future<Color> _extractColor(String id, String imageUrl) {
  final cached = _dominantColorCache[id];
  if (cached != null) return Future.value(cached);

  // Return existing future if already in flight.
  if (_pendingExtractions.containsKey(id)) {
    return _pendingExtractions[id]!.future;
  }

  final completer = Completer<Color>();
  _pendingExtractions[id] = completer;

  PaletteGenerator.fromImageProvider(
    NetworkImage(imageUrl),
    size: const Size(40, 56),
    maximumColorCount: 3,
  ).then((palette) {
    final color = palette.dominantColor?.color ?? Colors.deepPurpleAccent;
    _dominantColorCache[id] = color;
    completer.complete(color);
  }).catchError((_) {
    completer.complete(Colors.deepPurpleAccent);
  }).whenComplete(() {
    _pendingExtractions.remove(id);
  });

  return completer.future;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<PocketCard>> _cardsFuture;

  @override
  void initState() {
    super.initState();
    _cardsFuture = CardService().getAllCards();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TCGP Trading App'),
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
          return LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = (constraints.maxWidth ~/ 180).clamp(3, 4);
              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                padding: const EdgeInsets.all(10),
                itemCount: cards.length,
                itemBuilder: (context, index) {
                  return _CardTile(card: cards[index]);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _CardTile extends StatefulWidget {
  final PocketCard card;
  const _CardTile({required this.card});

  @override
  State<_CardTile> createState() => _CardTileState();
}

class _CardTileState extends State<_CardTile> {
  Color? _glowColor;

  @override
  void initState() {
    super.initState();
    final cached = _dominantColorCache[widget.card.id];
    if (cached != null) {
      _glowColor = cached;
    } else {
      _extractColor(widget.card.id, widget.card.imageUrl).then((color) {
        if (mounted) setState(() => _glowColor = color);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasGlow = _glowColor != null;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CardScreen(card: widget.card),
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: hasGlow
              ? [
                  BoxShadow(
                    // ignore: deprecated_member_use
                    color: _glowColor!.withOpacity(0.45),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            widget.card.imageUrl,
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
