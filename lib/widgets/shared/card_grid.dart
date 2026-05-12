import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/widgets/shared/set_header.dart';

class CardGrid extends StatelessWidget {
  final List<PocketCard> cards;
  final ScrollController scrollController;
  final Widget Function(PocketCard card) tileBuilder;
  final double bottomPadding;
  final Widget? bottomOverlay;

  const CardGrid({
    super.key,
    required this.cards,
    required this.scrollController,
    required this.tileBuilder,
    this.bottomPadding = 6,
    this.bottomOverlay,
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return Center(
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
      );
    }

    // Group cards by set, preserving relative order within each group
    final grouped = <String, List<PocketCard>>{};
    for (final card in cards) {
      grouped.putIfAbsent(card.set, () => []).add(card);
    }
    final setOrder = grouped.keys.toList();

    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = (constraints.maxWidth ~/ 180).clamp(3, 4);
            final gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 367 / 512,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            );

            return CustomScrollView(
              controller: scrollController,
              cacheExtent: constraints.maxHeight * 1.25,
              slivers: [
                for (int i = 0; i < setOrder.length; i++) ...[
                  SliverToBoxAdapter(
                    child: SetHeader(
                      setId: setOrder[i],
                      isFirst: i == 0,
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    sliver: SliverGrid(
                      gridDelegate: gridDelegate,
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final card = grouped[setOrder[i]]![index];
                          return tileBuilder(card);
                        },
                        childCount: grouped[setOrder[i]]!.length,
                      ),
                    ),
                  ),
                ],
                SliverPadding(
                  padding: EdgeInsets.only(bottom: bottomPadding),
                ),
              ],
            );
          },
        ),
        if (bottomOverlay != null) bottomOverlay!,
      ],
    );
  }
}
