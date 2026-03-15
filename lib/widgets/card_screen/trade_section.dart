import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/models/home_mode.dart';
import 'package:tcgp_trading_app/models/trade_match.dart';
import 'package:tcgp_trading_app/screens/chat_screen.dart';
import 'package:tcgp_trading_app/services/card_service.dart';
import 'package:tcgp_trading_app/services/user_card_service.dart';
import 'package:tcgp_trading_app/services/language_filter_service.dart';
import 'package:tcgp_trading_app/utils/activity_utils.dart';
import 'package:tcgp_trading_app/widgets/shared/optimized_card_image.dart';
import 'package:tcgp_trading_app/utils/languages.dart';
import 'package:tcgp_trading_app/widgets/home_screen/card_tile.dart';
import 'package:tcgp_trading_app/widgets/shared/app_dialog.dart';
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
  bool _myListedOnly = false;
  bool _myWishlistedOnly = false;
  Set<String> _pendingProposals = {};
  final Set<String> _languages = languages.keys.toSet();
  Set<String> _selectedLanguages = {...languages.keys};
  Set<String> _appliedLanguages = {...languages.keys};

  bool get _isFullArtSupporter => widget.card.fullart;

  /// Check if the current user has a pending trade proposal for this match.
  bool _hasProposal(PocketCard matchCard, TradeMatch tradeMatch) {
    final String offerCardId;
    final String receiveCardId;
    if (_activeTab == 0) {
      // "I want this card" → user offers matchCard, receives contextCard
      offerCardId = matchCard.id;
      receiveCardId = widget.card.id;
    } else {
      // "I have this card" → user offers contextCard, receives matchCard
      offerCardId = widget.card.id;
      receiveCardId = matchCard.id;
    }
    return _pendingProposals
        .contains('${tradeMatch.userId}:$offerCardId:$receiveCardId');
  }

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
                                    ', these are the cards you could offer for it.'),
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
                      onChanged: (value) {
                        setState(() {
                          _trainersOnly = value;
                          _wantMatches = null;
                          _ownedMatches = null;
                        });
                        _fetchMatches();
                      },
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
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 6, 0),
          child: Row(
            children: [
              Text(
                _activeTab == 0 ? 'My listings only' : 'My wishlist only',
                style: const TextStyle(fontSize: 13, color: Colors.white70),
              ),
              const SizedBox(width: 6),
              SizedBox(
                height: 32,
                child: FittedBox(
                  child: Switch(
                    value: _activeTab == 0 ? _myListedOnly : _myWishlistedOnly,
                    onChanged: (value) {
                      setState(() {
                        if (_activeTab == 0) {
                          _myListedOnly = value;
                        } else {
                          _myWishlistedOnly = value;
                        }
                      });
                    },
                    activeColor: const Color(0xFF02F8AE),
                    activeTrackColor: const Color(0xFF02F8AE).withOpacity(0.4),
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
    if (_loadingMatches) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (matches == null) return const SizedBox.shrink();

    // Apply client-side filter: "My listings only" / "My wishlist only"
    // Uses language-aware check (same logic as the checkmark icon overlay).
    if (_activeTab == 0 && _myListedOnly) {
      matches = matches
          .where(
              (m) => _userCardService.isOwned(m.$1.id, language: m.$2.language))
          .toList();
    } else if (_activeTab == 1 && _myWishlistedOnly) {
      matches = matches
          .where((m) =>
              _userCardService.isWishlisted(m.$1.id, language: m.$2.language))
          .toList();
    }

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
                            borderRadius: BorderRadius.circular(2),
                            child: OptimizedCardImage(
                              imageUrl: matchCard.imageUrl,
                              isThumbnail: true,
                              placeholder: (context, url) => Container(
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(2),
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
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ),
                          if (_userCardService.isWishlisted(
                                matchCard.id,
                                language: tradeMatch.language,
                              ) ||
                              _userCardService.isOwned(
                                matchCard.id,
                                language: tradeMatch.language,
                              ))
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
                                  _userCardService.isOwned(
                                    matchCard.id,
                                    language: tradeMatch.language,
                                  )
                                      ? Icons.check_circle
                                      : Icons.favorite,
                                  size: 14,
                                  color: const Color(0xFF02F8AE),
                                ),
                              ),
                            ),
                          if (_hasProposal(matchCard, tradeMatch))
                            Positioned(
                              bottom: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.8),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.swap_horiz,
                                  size: 14,
                                  color: Color(0xFF02F8AE),
                                ),
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

  Future<void> _navigateToChat(
      PocketCard matchCard, TradeMatch tradeMatch) async {
    // Determine languages for the trade message
    final String offerLanguage;
    final String receiveLanguage;
    final String offerCardId;
    final String receiveCardId;
    if (_activeTab == 0) {
      // "I want this card" tab: offerCard=matchCard, receiveCard=contextCard
      offerCardId = matchCard.id;
      receiveCardId = widget.card.id;
      offerLanguage = tradeMatch.language;
      final contextLangs =
          _userCardService.getLanguages(widget.card.id, 'wishlist');
      receiveLanguage = contextLangs.isNotEmpty ? contextLangs.first : '';
    } else {
      // "I have this card" tab: offerCard=contextCard, receiveCard=matchCard
      offerCardId = widget.card.id;
      receiveCardId = matchCard.id;
      final contextLangs =
          _userCardService.getLanguages(widget.card.id, 'owned');
      offerLanguage = contextLangs.isNotEmpty ? contextLangs.first : '';
      receiveLanguage = tradeMatch.language;
    }

    await Navigator.push(
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

    // Trade proposal is auto-sent when ChatScreen opens, so mark it locally
    if (!mounted) return;
    setState(() {
      _pendingProposals.add('${tradeMatch.userId}:$offerCardId:$receiveCardId');
    });
  }

  void _onMatchTapped(PocketCard matchCard, TradeMatch tradeMatch) {
    if (_hasProposal(matchCard, tradeMatch)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already sent a trade proposal to this user'),
        ),
      );
      return;
    }

    final needsWarning = _activeTab == 0
        ? !_userCardService.isOwned(
            matchCard.id,
            language: tradeMatch.language,
          )
        : !_userCardService.isWishlisted(
            matchCard.id,
            language: tradeMatch.language,
          );

    // Determine which card the user sends vs receives, and their languages
    final PocketCard sendCard;
    final PocketCard receiveCard;
    final String sendLanguage;
    final String receiveLanguage;
    if (_activeTab == 0) {
      // "I want this card" → user sends matchCard, receives contextCard
      sendCard = matchCard;
      receiveCard = widget.card;
      sendLanguage = tradeMatch.language;
      final contextLangs =
          _userCardService.getLanguages(widget.card.id, 'wishlist');
      receiveLanguage = contextLangs.isNotEmpty ? contextLangs.first : '';
    } else {
      // "I have this card" → user sends contextCard, receives matchCard
      sendCard = widget.card;
      receiveCard = matchCard;
      final contextLangs =
          _userCardService.getLanguages(widget.card.id, 'owned');
      sendLanguage = contextLangs.isNotEmpty ? contextLangs.first : '';
      receiveLanguage = tradeMatch.language;
    }

    final bool showWarning = needsWarning;

    showAppDialog<void>(
      context: context,
      title: 'Trade Preview',
      centerContent: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF2A2A30),
                backgroundImage: tradeMatch.icon != null
                    ? AssetImage('images/profile/${tradeMatch.icon}')
                    : null,
                child: tradeMatch.icon == null
                    ? Text(
                        tradeMatch.playerName.isNotEmpty
                            ? tradeMatch.playerName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            fontSize: 18, color: Colors.white70),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tradeMatch.playerName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: activityColor(tradeMatch.lastActiveAt),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        activityLabel(tradeMatch.lastActiveAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'You send',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white38,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: OptimizedCardImage(
                            imageUrl: sendCard.imageUrl,
                            isThumbnail: true,
                          ),
                        ),
                        if (sendLanguage.isNotEmpty)
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
                                sendLanguage,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sendCard.name,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.swap_horiz,
                  color: Color(0xFF02F8AE),
                  size: 28,
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'You receive',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white38,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: OptimizedCardImage(
                            imageUrl: receiveCard.imageUrl,
                            isThumbnail: true,
                          ),
                        ),
                        if (receiveLanguage.isNotEmpty)
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
                                receiveLanguage,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      receiveCard.name,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (showWarning)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 16, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style:
                            const TextStyle(fontSize: 12, color: Colors.amber),
                        children: [
                          TextSpan(
                            text: _activeTab == 0
                                ? 'You have not listed '
                                : 'You have not added ',
                          ),
                          TextSpan(
                            text: '${matchCard.name} ',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
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
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ),
                          TextSpan(
                            text: _activeTab == 0
                                ? ' for trade'
                                : ' to your wishlist',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      primaryText: 'Continue',
      onPrimaryAction: () => _navigateToChat(matchCard, tradeMatch),
    );
  }

  String _formatLanguages(String cardId, String type) {
    final langs = _userCardService.getLanguages(cardId, type);

    if (langs.isEmpty) return 'no languages';

    final formatted = langs
        .map((code) =>
            code == 'ANY' ? 'any language' : (languages[code] ?? code))
        .toList();

    if (formatted.length == 1) {
      return formatted.first;
    } else if (formatted.length == 2) {
      return '${formatted[0]} and ${formatted[1]}';
    } else {
      return '${formatted.sublist(0, formatted.length - 1).join(', ')} and ${formatted.last}';
    }
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

      futures.add(_userCardService.getMyPendingProposals().then((proposals) {
        _pendingProposals = proposals;
      }));

      final langList = _appliedLanguages.toList();

      final fullartOnly = _trainersOnly && _isFullArtSupporter;

      if (wantNeeded) {
        futures.add(_userCardService
            .getTradeMatchesForWanted(cardId, langList,
                fullartOnly: fullartOnly)
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
            .getTradeMatchesForOwned(cardId, langList, fullartOnly: fullartOnly)
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
      pendingLangs = isWishlist ? {'ANY'} : {'ENG'};
      pendingWishlist = isWishlist;
      pendingOwned = !isWishlist;
    }

    final isEditing = isWishlist ? _isWishlisted : _isOwned;
    final hasOppositeEntry = isWishlist ? _isOwned : _isWishlisted;
    final warningText = hasOppositeEntry
        ? isWishlist
            ? 'You have already listed this card for trade. Adding it to your wishlist will remove your listing.'
            : 'You have already wishlisted this card. Creating a listing will remove it from your wishlist.'
        : null;

    final result = await showDialog<
        ({bool wishlisted, bool owned, Set<String> languages})?>(
      context: context,
      builder: (context) => _EditCardDialog(
        card: widget.card,
        initialWishlist: pendingWishlist,
        initialOwned: pendingOwned,
        initialLanguages: pendingLangs,
        type: type,
        isEditing: isEditing,
        warningText: warningText,
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
  final bool isEditing;
  final String? warningText;

  const _EditCardDialog({
    required this.card,
    required this.initialWishlist,
    required this.initialOwned,
    required this.initialLanguages,
    required this.type,
    required this.isEditing,
    this.warningText,
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

  String get dialogTitle {
    if (widget.type == 'wishlist') {
      return widget.isEditing ? 'Edit Wishlist' : 'Add to Wishlist';
    }
    return widget.isEditing ? 'Edit Listing' : 'Create a Listing';
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      centerContent: true,
      title: dialogTitle,
      content: Column(
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
              onWishlistToggle: widget.type == 'wishlist'
                  ? (langs) {
                      setState(() {
                        _wishlisted = !_wishlisted;
                        if (_wishlisted) {
                          _owned = false;
                          _languages = langs;
                        }
                      });
                    }
                  : null,
              onOwnedToggle: widget.type == 'owned'
                  ? (langs) {
                      setState(() {
                        _owned = !_owned;
                        if (_owned) {
                          _wishlisted = false;
                          _languages = langs;
                        }
                      });
                    }
                  : null,
              onLanguagesChanged: (_, langs) {
                setState(() => _languages = langs);
              },
            ),
          ),
          if (widget.warningText != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 16, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.warningText!,
                      style: const TextStyle(fontSize: 12, color: Colors.amber),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      onPrimaryPressed: () => (
        wishlisted: _wishlisted,
        owned: _owned,
        languages: _languages,
      ),
    );
  }
}
