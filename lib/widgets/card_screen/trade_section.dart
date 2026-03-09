import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/models/home_mode.dart';
import 'package:tcgp_trading_app/models/trade_match.dart';
import 'package:tcgp_trading_app/screens/chat_screen.dart';
import 'package:tcgp_trading_app/services/card_service.dart';
import 'package:tcgp_trading_app/services/user_card_service.dart';
import 'package:tcgp_trading_app/services/language_filter_service.dart';
import 'package:tcgp_trading_app/utils/activity_utils.dart';
import 'package:tcgp_trading_app/utils/languages.dart';
import 'package:tcgp_trading_app/widgets/home_screen/card_tile.dart';
import 'package:flutter/gestures.dart';

class TradeSection extends StatefulWidget {
  final PocketCard card;

  const TradeSection({super.key, required this.card});

  @override
  State<TradeSection> createState() => _TradeSectionState();
}

class _TradeSectionState extends State<TradeSection>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final activeColor = const Color(0xFF02F8AE);
  final inactiveColor = Colors.white60;
  final _userCardService = UserCardService();
  final _langFilterService = LanguageFilterService();
  int _activeTab = 0;
  bool _isWishlisted = false;
  bool _isOwned = false;
  List<(PocketCard, TradeMatch)>? _wantMatches;
  List<(PocketCard, TradeMatch)>? _ownedMatches;
  bool _loadingMatches = false;
  bool _trainersOnly = false;
  final Set<String> _languages = languages.keys.toSet();
  Set<String> _selectedLanguages = {...languages.keys};
  Set<String> _appliedLanguages = {...languages.keys};

  bool get _isFullArtSupporter =>
      widget.card.rarity == '☆☆' && widget.card.type == 'Trainer';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _activeTab = _tabController.index);
      }
    });
    _loadLanguageFilter();
    _loadState();
  }

  Future<void> _loadLanguageFilter() async {
    final saved = await _langFilterService.getSelectedLanguages();
    if (!mounted) return;
    setState(() {
      _selectedLanguages = saved;
      _appliedLanguages = {...saved};
    });
  }

  void _updateLanguageFilter(Set<String> selected) {
    setState(() => _selectedLanguages = selected);
  }

  void _applyLanguageFilter() {
    setState(() {
      _appliedLanguages = {..._selectedLanguages};
      _wantMatches = null;
      _ownedMatches = null;
    });
    _langFilterService.setSelectedLanguages(_selectedLanguages);
    _fetchMatches();
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
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: TabBar(
            controller: _tabController,
            indicator: const UnderlineTabIndicator(
              borderSide: BorderSide(
                color: Color(0xFF02F8AE),
                width: 2,
              ),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerHeight: 0,
            labelColor: const Color(0xFF02F8AE),
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
                    Icon(Icons.favorite_border, size: 16),
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
                    Icon(Icons.check_circle_outline, size: 16),
                    SizedBox(width: 6),
                    Text('I have this card'),
                  ],
                ),
              )
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
                        ? (_isWishlisted
                            ? [
                                const TextSpan(text: 'You have wishlisted '),
                                TextSpan(
                                  text: card.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white70,
                                  ),
                                ),
                                TextSpan(
                                    text:
                                        ' in ${_formatLanguages(card.id, 'wishlist')}. '),
                                TextSpan(
                                  text: 'Edit',
                                  style: const TextStyle(
                                    color: Color(0xFF02F8AE),
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      _showEditCardDialog('wishlist');
                                    },
                                ),
                              ]
                            : [
                                const TextSpan(
                                    text: 'You have not wishlisted '),
                                TextSpan(
                                  text: card.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white70,
                                  ),
                                ),
                                const TextSpan(text: ' yet. '),
                                TextSpan(
                                  text: 'Wishlist now',
                                  style: const TextStyle(
                                    color: Color(0xFF02F8AE),
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      _onWantPressed();
                                    },
                                ),
                              ])
                        : (_isOwned
                            ? [
                                const TextSpan(text: 'You have listed '),
                                TextSpan(
                                  text: card.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white70,
                                  ),
                                ),
                                TextSpan(
                                    text:
                                        ' for trade in ${_formatLanguages(card.id, 'owned')}. '),
                                TextSpan(
                                  text: 'Edit',
                                  style: const TextStyle(
                                    color: Color(0xFF02F8AE),
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      _showEditCardDialog('owned');
                                    },
                                ),
                              ]
                            : [
                                const TextSpan(text: 'You have not listed '),
                                TextSpan(
                                  text: card.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white70,
                                  ),
                                ),
                                const TextSpan(text: ' for trade yet. '),
                                TextSpan(
                                  text: 'List now',
                                  style: const TextStyle(
                                    color: Color(0xFF02F8AE),
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      _onCanTradePressed();
                                    },
                                ),
                              ]),
                  ),
                ),
              ),
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
                                    ' and you are willing to trade for it, these are the cards you could offer in return.'),
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
                                    ' and you are willing to trade it, these are the cards you could ask for in return.'),
                          ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected:
                            _selectedLanguages.length == _languages.length,
                        onSelected: (selected) {
                          _updateLanguageFilter(
                            selected ? {..._languages} : {},
                          );
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
                              final updated = {..._selectedLanguages};
                              if (selected) {
                                updated.add(lang);
                              } else {
                                updated.remove(lang);
                              }
                              _updateLanguageFilter(updated);
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
              if (_selectedLanguages.length != _appliedLanguages.length ||
                  !_selectedLanguages.containsAll(_appliedLanguages))
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: SizedBox(
                    height: 32,
                    child: FilledButton.icon(
                      onPressed: _applyLanguageFilter,
                      icon: const Icon(Icons.check, size: 14),
                      label:
                          const Text('Apply', style: TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF02F8AE),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_isFullArtSupporter)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 6, 0),
            child: Row(
              children: [
                const Text(
                  'Full Art Supporters only',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
                SizedBox(width: 6),
                SizedBox(
                  height: 32,
                  child: FittedBox(
                    child: Switch(
                      value: _trainersOnly,
                      onChanged: (value) =>
                          setState(() => _trainersOnly = value),
                      activeColor: const Color(0xFF02F8AE),
                      activeTrackColor:
                          const Color(0xFF02F8AE).withOpacity(0.4),
                      inactiveThumbColor: Colors.white38,
                      inactiveTrackColor: Colors.white10,
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
    var matches = _activeTab == 0 ? _wantMatches : _ownedMatches;
    if (matches != null && _trainersOnly) {
      matches = matches.where((pair) => pair.$1.type == 'Trainer').toList();
    }
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth - 8 * 3) / 4;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: matches!.map((match) {
              final (matchCard, tradeMatch) = match;
              return SizedBox(
                width: itemWidth,
                child: GestureDetector(
                  onTap: () => _onMatchTapped(matchCard, tradeMatch),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
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
                              errorWidget: (context, url, error) => const Icon(
                                  Icons.broken_image,
                                  color: Colors.white24),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Text(
                                tradeMatch.language,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ),
                          if (_userCardService.isWishlisted(matchCard.id) ||
                              _userCardService.isOwned(matchCard.id))
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.8),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _userCardService.isOwned(matchCard.id)
                                      ? Icons.check_circle
                                      : Icons.favorite,
                                  size: 14,
                                  color: const Color(0xFF02F8AE),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: activityColor(tradeMatch.lastActiveAt),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              tradeMatch.playerName,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white54,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  void _navigateToChat(PocketCard matchCard, TradeMatch tradeMatch) {
    // Determine languages for the trade message
    final String offerLanguage;
    final String receiveLanguage;
    if (_activeTab == 0) {
      // "I want this card" tab: offerCard=matchCard, receiveCard=contextCard
      offerLanguage = tradeMatch.language;
      final contextLangs =
          _userCardService.getLanguages(widget.card.id, 'wishlist');
      receiveLanguage = contextLangs.isNotEmpty ? contextLangs.first : '';
    } else {
      // "I have this card" tab: offerCard=contextCard, receiveCard=matchCard
      final contextLangs =
          _userCardService.getLanguages(widget.card.id, 'owned');
      offerLanguage = contextLangs.isNotEmpty ? contextLangs.first : '';
      receiveLanguage = tradeMatch.language;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          contextCard: widget.card,
          matchCard: matchCard,
          tradeMatch: tradeMatch,
          isWantTab: _activeTab == 0,
          offerLanguage: offerLanguage,
          receiveLanguage: receiveLanguage,
        ),
      ),
    );
  }

  void _onMatchTapped(PocketCard matchCard, TradeMatch tradeMatch) {
    final needsWarning = _activeTab == 0
        ? !_userCardService.isOwned(matchCard.id)
        : !_userCardService.isWishlisted(matchCard.id);

    if (!needsWarning) {
      _navigateToChat(matchCard, tradeMatch);
      return;
    }

    final action = _activeTab == 0 ? 'listed' : 'added';
    final listName = _activeTab == 0 ? 'for trade' : 'to your wishlist';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Heads up',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You have not $action ${matchCard.name} $listName.',
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _navigateToChat(matchCard, tradeMatch);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF02F8AE),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Continue'),
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

  String _formatLanguages(String cardId, String type) {
    final langs = _userCardService.getLanguages(cardId, type);
    if (langs.isEmpty) return 'no languages';
    return langs
        .map((code) =>
            code == 'ANY' ? 'any language' : (languages[code] ?? code))
        .join(', ');
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
    final wantNeeded = _wantMatches == null;
    final ownedNeeded = _ownedMatches == null;
    if (!wantNeeded && !ownedNeeded) return;

    setState(() => _loadingMatches = true);

    try {
      final cardMap = CardService().getCardMap();
      final futures = <Future>[];

      final langList = _appliedLanguages.toList();

      if (wantNeeded) {
        futures.add(_userCardService
            .getTradeMatchesForWanted(cardId, langList)
            .then((matches) {
          _wantMatches = matches
              .where((m) => cardMap.containsKey(m.cardId))
              .map((m) => (cardMap[m.cardId]!, m))
              .where((pair) => pair.$1.rarity == widget.card.rarity)
              .toList();
        }));
      }

      if (ownedNeeded) {
        futures.add(_userCardService
            .getTradeMatchesForOwned(cardId, langList)
            .then((matches) {
          _ownedMatches = matches
              .where((m) => cardMap.containsKey(m.cardId))
              .map((m) => (cardMap[m.cardId]!, m))
              .where((pair) => pair.$1.rarity == widget.card.rarity)
              .toList();
        }));
      }

      await Future.wait(futures);
    } catch (e) {
      _wantMatches ??= [];
      _ownedMatches ??= [];
    }

    if (!mounted) return;
    setState(() => _loadingMatches = false);
  }

  Future<void> _onWantPressed() async {
    await _showEditCardDialog('wishlist');
  }

  Future<void> _onCanTradePressed() async {
    await _showEditCardDialog('owned');
  }

  Future<void> _showEditCardDialog(String type) async {
    final cardId = widget.card.id;
    final isWishlist = type == 'wishlist';

    // Only show the relevant type active based on which tab opened the dialog
    bool pendingWishlist = isWishlist && _isWishlisted;
    bool pendingOwned = !isWishlist && _isOwned;
    Set<String> pendingLangs = _userCardService.getLanguages(cardId, type);
    if (pendingLangs.isEmpty) {
      pendingLangs = {'ANY'};
      pendingWishlist = isWishlist;
      pendingOwned = !isWishlist;
    }

    final result = await showDialog<
        ({bool wishlisted, bool owned, Set<String> languages})?>(
      context: context,
      builder: (context) => _EditCardDialog(
        card: widget.card,
        initialWishlist: pendingWishlist,
        initialOwned: pendingOwned,
        initialLanguages: pendingLangs,
        type: type,
      ),
    );

    if (result == null || !mounted) return;

    try {
      // Sync both types by comparing before/after
      for (final t in ['wishlist', 'owned']) {
        final wasActive = t == 'wishlist' ? _isWishlisted : _isOwned;
        final isNowActive = t == 'wishlist' ? result.wishlisted : result.owned;
        final oldLangs = _userCardService.getLanguages(cardId, t);

        if (wasActive && !isNowActive) {
          // Remove all entries for this type
          for (final lang in oldLangs) {
            await _userCardService.removeCard(cardId, t, lang);
          }
        } else if (isNowActive) {
          // Remove languages no longer selected
          for (final lang in oldLangs) {
            if (!result.languages.contains(lang)) {
              await _userCardService.removeCard(cardId, t, lang);
            }
          }
          // Add new languages
          for (final lang in result.languages) {
            if (!oldLangs.contains(lang)) {
              await _userCardService.addCard(cardId, t, lang);
            }
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: $e')),
      );
    }

    if (!mounted) return;
    _refreshState();
  }
}

class _EditCardDialog extends StatefulWidget {
  final PocketCard card;
  final bool initialWishlist;
  final bool initialOwned;
  final Set<String> initialLanguages;
  final String type;

  const _EditCardDialog({
    required this.card,
    required this.initialWishlist,
    required this.initialOwned,
    required this.initialLanguages,
    required this.type,
  });

  @override
  State<_EditCardDialog> createState() => _EditCardDialogState();
}

class _EditCardDialogState extends State<_EditCardDialog> {
  late bool _wishlisted;
  late bool _owned;
  late Set<String> _languages;

  @override
  void initState() {
    super.initState();
    _wishlisted = widget.initialWishlist;
    _owned = widget.initialOwned;
    _languages = Set.from(widget.initialLanguages);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 140,
              height: 200,
              child: CardTile(
                card: widget.card,
                mode: HomeMode.edit,
                isPendingWishlist: _wishlisted,
                isPendingOwned: _owned,
                pendingLanguages: _languages,
                onWishlistToggle: (langs) {
                  setState(() {
                    _wishlisted = !_wishlisted;
                    if (_wishlisted) {
                      _owned = false;
                      _languages = langs;
                    }
                  });
                },
                onOwnedToggle: (langs) {
                  setState(() {
                    _owned = !_owned;
                    if (_owned) {
                      _wishlisted = false;
                      _languages = langs;
                    }
                  });
                },
                onLanguagesChanged: (_, langs) {
                  setState(() => _languages = langs);
                },
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(context, (
                        wishlisted: _wishlisted,
                        owned: _owned,
                        languages: _languages,
                      ));
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF02F8AE),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
