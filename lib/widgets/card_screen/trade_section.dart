import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/services/user_card_service.dart';
import 'package:tcgp_trading_app/widgets/shared/language_selector.dart';

class TradeSection extends StatefulWidget {
  final PocketCard card;

  const TradeSection({super.key, required this.card});

  @override
  State<TradeSection> createState() => _TradeSectionState();
}

class _TradeSectionState extends State<TradeSection>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _userCardService = UserCardService();
  int _activeTab = 0;
  bool _isWishlisted = false;
  bool _isOwned = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _activeTab = _tabController.index);
      }
    });
    _loadState();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: [
              Expanded(
                child: _isWishlisted
                    ? FilledButton.icon(
                        onPressed: _onWantPressed,
                        icon: const Icon(Icons.favorite, size: 18),
                        label: const Text('I want this card'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF02F8AE),
                          foregroundColor: Colors.black,
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: _onWantPressed,
                        icon: const Icon(Icons.favorite_outline, size: 18),
                        label: const Text('I want this card'),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _isOwned
                    ? FilledButton.icon(
                        onPressed: _onCanTradePressed,
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('I have this card'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF02F8AE),
                          foregroundColor: Colors.black,
                        ),
                      )
                    : OutlinedButton.icon(
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
              Tab(height: 36, text: 'I want this card'),
              Tab(height: 36, text: 'I have this card')
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
        const SizedBox(height: 16),
      ],
    );
  }

  void _loadState() {
    _userCardService.loadMyCards().then((_) {
      if (!mounted) return;
      setState(() {
        _isWishlisted = _userCardService.isWishlisted(widget.card.id);
        _isOwned = _userCardService.isOwned(widget.card.id);
      });
    });
  }

  void _refreshState() {
    setState(() {
      _isWishlisted = _userCardService.isWishlisted(widget.card.id);
      _isOwned = _userCardService.isOwned(widget.card.id);
    });
  }

  Future<void> _onWantPressed() async {
    await _showLanguageSheet('wishlist');
  }

  Future<void> _onCanTradePressed() async {
    await _showLanguageSheet('owned');
  }

  Future<void> _showLanguageSheet(String type) async {
    final cardId = widget.card.id;
    final title = type == 'wishlist'
        ? 'Select languages you want'
        : 'Select languages you have';

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => LanguageSelector(
        title: title,
        selectedLanguages: _userCardService.getLanguages(cardId, type),
        onToggle: (lang, selected) async {
          try {
            if (selected) {
              await _userCardService.addCard(cardId, type, lang);
            } else {
              await _userCardService.removeCard(cardId, type, lang);
            }
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to update: $e')),
            );
          }
        },
      ),
    );
    if (!mounted) return;
    _refreshState();
  }
}
