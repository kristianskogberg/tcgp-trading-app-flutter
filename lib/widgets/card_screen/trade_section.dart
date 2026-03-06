import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/screens/card_screen.dart';
import 'package:tcgp_trading_app/services/card_service.dart';
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
  List<PocketCard>? _wantMatches;
  List<PocketCard>? _ownedMatches;
  bool _loadingMatches = false;

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
        _buildMatchGrid(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMatchGrid() {
    final matches = _activeTab == 0 ? _wantMatches : _ownedMatches;
    final isActive = _activeTab == 0 ? _isWishlisted : _isOwned;

    if (!isActive) return const SizedBox.shrink();

    if (_loadingMatches) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (matches == null) return const SizedBox.shrink();

    if (matches.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24, horizontal: 6),
        child: Center(
          child: Text(
            'No trade matches found',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 0.7,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: matches.length,
        itemBuilder: (context, index) {
          final matchCard = matches[index];
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CardScreen(card: matchCard),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: matchCard.imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => Container(
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.broken_image, color: Colors.white24),
              ),
            ),
          );
        },
      ),
    );
  }

  void _loadState() {
    _userCardService.loadMyCards().then((_) {
      if (!mounted) return;
      setState(() {
        _isWishlisted = _userCardService.isWishlisted(widget.card.id);
        _isOwned = _userCardService.isOwned(widget.card.id);
      });
      _fetchMatches();
    });
  }

  void _refreshState() {
    setState(() {
      _isWishlisted = _userCardService.isWishlisted(widget.card.id);
      _isOwned = _userCardService.isOwned(widget.card.id);
      _wantMatches = null;
      _ownedMatches = null;
    });
    _fetchMatches();
  }

  Future<void> _fetchMatches() async {
    final cardId = widget.card.id;
    final wantNeeded = _isWishlisted && _wantMatches == null;
    final ownedNeeded = _isOwned && _ownedMatches == null;
    if (!wantNeeded && !ownedNeeded) return;

    setState(() => _loadingMatches = true);

    try {
      final cardMap = CardService().getCardMap();
      final futures = <Future>[];

      if (wantNeeded) {
        futures
            .add(_userCardService.getTradeMatchesForWanted(cardId).then((ids) {
          _wantMatches = ids
              .where((id) => cardMap.containsKey(id))
              .map((id) => cardMap[id]!)
              .toList();
        }));
      }

      if (ownedNeeded) {
        futures
            .add(_userCardService.getTradeMatchesForOwned(cardId).then((ids) {
          _ownedMatches = ids
              .where((id) => cardMap.containsKey(id))
              .map((id) => cardMap[id]!)
              .toList();
        }));
      }

      await Future.wait(futures);
    } catch (_) {
      _wantMatches ??= [];
      _ownedMatches ??= [];
    }

    if (!mounted) return;
    setState(() => _loadingMatches = false);
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
