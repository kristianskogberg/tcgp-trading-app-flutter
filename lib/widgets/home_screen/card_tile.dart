import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/screens/card_screen.dart';

class CardTile extends StatelessWidget {
  final PocketCard card;
  const CardTile({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
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
          child: CachedNetworkImage(
            imageUrl: card.imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => const _CardSkeleton(),
            errorWidget: (context, url, error) =>
                const Icon(Icons.broken_image, color: Colors.white24),
          ),
        ),
      ),
    );
  }
}

class _CardSkeleton extends StatefulWidget {
  const _CardSkeleton();

  @override
  State<_CardSkeleton> createState() => _CardSkeletonState();
}

class _CardSkeletonState extends State<_CardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _colorAnimation = ColorTween(
      begin: const Color(0xFF1A1A1E),
      end: const Color(0xFF2A2A30),
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ColoredBox(color: _colorAnimation.value!);
      },
    );
  }
}
