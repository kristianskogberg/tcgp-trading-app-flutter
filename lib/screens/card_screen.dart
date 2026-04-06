import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:tcgp_trading_app/config/app_colors.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/models/feedback_submission.dart';
import 'package:tcgp_trading_app/services/feedback_service.dart';
import 'package:tcgp_trading_app/utils/rarity_utils.dart';
import 'package:tcgp_trading_app/widgets/card_screen/card_detail_header.dart';
import 'package:tcgp_trading_app/widgets/card_screen/sticky_tab_bar_delegate.dart';
import 'package:tcgp_trading_app/widgets/card_screen/trade_section.dart';
import 'package:tcgp_trading_app/widgets/shared/app_dialog.dart';

class CardScreen extends StatefulWidget {
  final PocketCard card;
  final String? heroTag;
  const CardScreen({super.key, required this.card, this.heroTag});

  @override
  State<CardScreen> createState() => _CardScreenState();
}

class _CardScreenState extends State<CardScreen>
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();
  final _tradeSectionKey = GlobalKey<TradeSectionState>();
  late final TabController _tabController;
  int _activeTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _activeTab = _tabController.index);
      }
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _tradeSectionKey.currentState?.loadMore();
    }
  }

  void _showReportDialog(BuildContext context) {
    final controller = TextEditingController();
    showAppDialog(
      context: context,
      title: 'Report card issue',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.card.name} (${widget.card.set} #${widget.card.number})',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLines: 3,
            maxLength: 100,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText:
                  'Describe the issue (e.g. wrong image, incorrect name or set…)',
              hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFF141418),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.white24),
              ),
            ),
          ),
        ],
      ),
      primaryText: 'Submit',
      onPrimaryAction: () {
        final description = controller.text.trim();
        if (description.isEmpty) return;
        FeedbackService()
            .submitFeedback(
          type: FeedbackType.cardReport,
          description: description,
          cardId: widget.card.id,
        )
            .then((_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Report submitted. Thank you!')),
            );
          }
        });
      },
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: TabBar(
          controller: _tabController,
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(
              color:
                  _activeTab == 0 ? AppColors.primary : AppColors.secondary,
              width: 2,
            ),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerHeight: 0,
          labelColor:
              _activeTab == 0 ? AppColors.primary : AppColors.secondary,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 14,
          ),
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          tabs: [
            Tab(
              height: 36,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PhosphorIcon(PhosphorIcons.heartStraight(), size: 16),
                  SizedBox(width: 6),
                  Text('I want this card'),
                ],
              ),
            ),
            Tab(
              height: 36,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PhosphorIcon(PhosphorIcons.checkCircle(), size: 16),
                  SizedBox(width: 6),
                  Text('I have this card'),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUntradable = isCardUntradable(widget.card.rarity, widget.card.pack);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                widget.card.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${widget.card.set} | #${widget.card.number}',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: PhosphorIcon(PhosphorIcons.dotsThreeVertical()),
            color: const Color(0xFF242429),
            surfaceTintColor: Colors.transparent,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            position: PopupMenuPosition.under,
            onSelected: (value) {
              if (value == 'report') {
                _showReportDialog(context);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                height: 44,
                value: 'report',
                child: Row(
                  children: [
                    PhosphorIcon(PhosphorIcons.flag(),
                        size: 20, color: Colors.white70),
                    SizedBox(width: 12),
                    Text('Report an issue',
                        style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: CardDetailHeader(
                card: widget.card, heroTag: widget.heroTag),
          ),
          if (isUntradable)
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(6, 10, 6, 24),
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
                        'This card is currently not available for trading.',
                        style: const TextStyle(
                            fontSize: 13, color: Colors.white54),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            SliverPersistentHeader(
              pinned: true,
              delegate: StickyTabBarDelegate(
                height: 44,
                child: _buildTabBar(),
              ),
            ),
            SliverToBoxAdapter(
              child: TradeSection(
                key: _tradeSectionKey,
                card: widget.card,
                activeTab: _activeTab,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
