import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:tcgp_trading_app/config/app_colors.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/models/home_mode.dart';
import 'package:tcgp_trading_app/models/trade_match.dart';
import 'package:tcgp_trading_app/screens/chat_screen.dart';
import 'package:tcgp_trading_app/screens/trade_condition_picker_screen.dart';
import 'package:tcgp_trading_app/services/card_service.dart';
import 'package:tcgp_trading_app/services/user_card_service.dart';
import 'package:tcgp_trading_app/services/language_filter_service.dart';
import 'package:tcgp_trading_app/utils/activity_utils.dart';
import 'package:tcgp_trading_app/utils/constants.dart';
import 'package:tcgp_trading_app/widgets/shared/card_badge.dart';
import 'package:tcgp_trading_app/widgets/shared/optimized_card_image.dart';
import 'package:tcgp_trading_app/widgets/shared/trade_card_pair.dart';
import 'package:tcgp_trading_app/utils/languages.dart';
import 'package:tcgp_trading_app/widgets/shared/card_tile.dart';
import 'package:tcgp_trading_app/widgets/shared/app_dialog.dart';
import 'package:flutter/gestures.dart';

class TradeSection extends StatefulWidget {
  final PocketCard card;
  final int activeTab;

  const TradeSection({super.key, required this.card, required this.activeTab});

  @override
  TradeSectionState createState() => TradeSectionState();
}

class TradeSectionState extends State<TradeSection> {
  static const _pageSize = 30;

  final _userCardService = UserCardService();
  final _langFilterService = LanguageFilterService();
  bool _isWishlisted = false;
  bool _isOwned = false;
  List<(PocketCard, TradeMatch)>? _wantMatches;
  List<(PocketCard, TradeMatch)>? _ownedMatches;
  bool _loadingMatches = false;
  bool _loadingMore = false;
  int _wantOffset = 0;
  int _ownedOffset = 0;
  bool _wantHasMore = true;
  bool _ownedHasMore = true;
  bool _trainersOnly = false;
  bool _myListedOnly = false;
  bool _myWishlistedOnly = false;
  Set<String> _pendingProposals = {};
  final Set<String> _languages = languages.keys.toSet();
  Set<String> _selectedLanguages = {...languages.keys};
  Set<String> _appliedLanguages = {...languages.keys};

  bool get _isFullArtSupporter =>
      widget.card.rarity == '☆☆' &&
      widget.card.cardType.toLowerCase() == 'supporter';

  /// Check if the current user has a pending trade proposal for this match.
  bool _hasProposal(PocketCard matchCard, TradeMatch tradeMatch) {
    final String offerCardId;
    final String receiveCardId;
    if (widget.activeTab == 0) {
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
      _wantOffset = 0;
      _ownedOffset = 0;
      _wantHasMore = true;
      _ownedHasMore = true;
    });
    _langFilterService.setSelectedLanguages(_selectedLanguages);
    _fetchMatches();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              PhosphorIcon(PhosphorIcons.info(),
                  size: 16, color: Colors.white38),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                    children: widget.activeTab == 0
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
                                    color: AppColors.primary,
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
                                    color: AppColors.primary,
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
                                if (_userCardService
                                    .hasTradeConditions(card.id))
                                  TextSpan(
                                    text:
                                        'Accepting ${_userCardService.getTradeConditionCount(card.id)} specific ${_userCardService.getTradeConditionCount(card.id) == 1 ? 'card' : 'cards'}. ',
                                  ),
                                TextSpan(
                                  text: 'Edit',
                                  style: const TextStyle(
                                    color: AppColors.secondary,
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
                                    color: AppColors.secondary,
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
              PhosphorIcon(PhosphorIcons.info(),
                  size: 16, color: Colors.white38),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                    children: widget.activeTab == 0
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
                        checkmarkColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: _selectedLanguages.length == _languages.length
                              ? AppColors.primary
                              : Colors.white70,
                          fontSize: 12,
                        ),
                        backgroundColor: const Color(0xFF1E1E24),
                        side: BorderSide(
                          color: _selectedLanguages.length == _languages.length
                              ? AppColors.primary
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
                            checkmarkColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.white70,
                              fontSize: 12,
                            ),
                            backgroundColor: const Color(0xFF1E1E24),
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.primary
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
                      icon: PhosphorIcon(PhosphorIcons.checkSquare(),
                          size: 14, color: Colors.white38),
                      label:
                          const Text('Apply', style: TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
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
                          _wantOffset = 0;
                          _ownedOffset = 0;
                          _wantHasMore = true;
                          _ownedHasMore = true;
                        });
                        _fetchMatches();
                      },
                      activeColor: AppColors.primary,
                      activeTrackColor: AppColors.primary.withOpacity(0.4),
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
                widget.activeTab == 0 ? 'My listings only' : 'My wishlist only',
                style: const TextStyle(fontSize: 13, color: Colors.white70),
              ),
              const SizedBox(width: 6),
              SizedBox(
                height: 32,
                child: FittedBox(
                  child: Switch(
                    value: widget.activeTab == 0 ? _myListedOnly : _myWishlistedOnly,
                    onChanged: (value) {
                      setState(() {
                        if (widget.activeTab == 0) {
                          _myListedOnly = value;
                        } else {
                          _myWishlistedOnly = value;
                        }
                      });
                    },
                    activeColor: AppColors.primary,
                    activeTrackColor: AppColors.primary.withOpacity(0.4),
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
    var matches = widget.activeTab == 0 ? _wantMatches : _ownedMatches;
    final hasMore = widget.activeTab == 0 ? _wantHasMore : _ownedHasMore;

    if (_loadingMatches) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (matches == null) return const SizedBox.shrink();

    // Apply trade conditions filter on "I have this card" tab
    if (widget.activeTab == 1 &&
        _userCardService.hasTradeConditions(widget.card.id)) {
      final conditions = _userCardService.getTradeConditions(widget.card.id);
      matches = matches.where((m) => conditions.containsKey(m.$1.id)).toList();
    }

    // Apply client-side filter: "My listings only" / "My wishlist only"
    // Uses language-aware check (same logic as the checkmark icon overlay).
    if (widget.activeTab == 0 && _myListedOnly) {
      matches = matches
          .where(
              (m) => _userCardService.isOwned(m.$1.id, language: m.$2.language))
          .toList();
    } else if (widget.activeTab == 1 && _myWishlistedOnly) {
      matches = matches
          .where((m) =>
              _userCardService.isWishlisted(m.$1.id, language: m.$2.language))
          .toList();
    }

    if (matches.isEmpty && !hasMore) {
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

    final itemCount = matches.length + (_loadingMore ? 1 : 0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.72,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index >= matches!.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          final (matchCard, tradeMatch) = matches[index];
          return GestureDetector(
            onTap: () => _onMatchTapped(matchCard, tradeMatch),
            child: Stack(
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
                    errorWidget: (context, url, error) => PhosphorIcon(
                        PhosphorIcons.imageBroken(),
                        color: Colors.white24),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color:
                          Colors.black.withOpacity(UIConstants.buttonOpacity),
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
                    child: CardBadge(
                      type: _userCardService.isOwned(
                        matchCard.id,
                        language: tradeMatch.language,
                      )
                          ? CardBadgeType.matchOwned
                          : CardBadgeType.matchWishlisted,
                    ),
                  ),
                if (_hasProposal(matchCard, tradeMatch))
                  const Positioned(
                    bottom: 4,
                    left: 4,
                    child: CardBadge(type: CardBadgeType.pendingTrade),
                  ),
              ],
            ),
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
    if (widget.activeTab == 0) {
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
          isWantTab: widget.activeTab == 0,
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
          content: Text(
              'You already sent a trade proposal to this user for this card'),
        ),
      );
      return;
    }

    final needsWarning = widget.activeTab == 0
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
    if (widget.activeTab == 0) {
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
          TradeCardPair(
            leftCard: sendCard,
            rightCard: receiveCard,
            leftTopLabel: 'You send',
            rightTopLabel: '${tradeMatch.playerName} sends',
            leftBottomLabel: sendCard.name,
            rightBottomLabel: receiveCard.name,
            leftLanguage: sendLanguage,
            rightLanguage: receiveLanguage,
            rightActivityColor: activityColor(tradeMatch.lastActiveAt),
          ),
          if (showWarning)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  PhosphorIcon(PhosphorIcons.warning(),
                      size: 16, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style:
                            const TextStyle(fontSize: 12, color: Colors.amber),
                        children: [
                          TextSpan(
                            text: widget.activeTab == 0
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
                                color: Colors.black
                                    .withOpacity(UIConstants.buttonOpacity),
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
                            text: widget.activeTab == 0
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
      _wantOffset = 0;
      _ownedOffset = 0;
      _wantHasMore = true;
      _ownedHasMore = true;
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
                fullartOnly: fullartOnly, limit: _pageSize, offset: 0)
            .then((matches) {
          final mapped = matches
              .where((m) => cardMap.containsKey(m.cardId))
              .map((m) => (cardMap[m.cardId]!, m))
              .toList();
          _wantMatches = mapped;
          _wantOffset = _pageSize;
          _wantHasMore = matches.length >= _pageSize;
        }));
      }

      if (ownedNeeded) {
        futures.add(_userCardService
            .getTradeMatchesForOwned(cardId, langList,
                fullartOnly: fullartOnly, limit: _pageSize, offset: 0)
            .then((matches) {
          final mapped = matches
              .where((m) => cardMap.containsKey(m.cardId))
              .map((m) => (cardMap[m.cardId]!, m))
              .toList();
          _ownedMatches = mapped;
          _ownedOffset = _pageSize;
          _ownedHasMore = matches.length >= _pageSize;
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

  void loadMore() {
    if (_loadingMatches || _loadingMore) return;
    final hasMore = widget.activeTab == 0 ? _wantHasMore : _ownedHasMore;
    final matches = widget.activeTab == 0 ? _wantMatches : _ownedMatches;
    if (!hasMore || matches == null) return;
    _loadMoreMatches();
  }

  Future<void> _loadMoreMatches() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);

    try {
      final cardId = widget.card.id;
      final cardMap = CardService().getCardMap();
      final langList = _appliedLanguages.toList();
      final fullartOnly = _trainersOnly && _isFullArtSupporter;
      final offset = widget.activeTab == 0 ? _wantOffset : _ownedOffset;

      final List<TradeMatch> matches;
      if (widget.activeTab == 0) {
        matches = await _userCardService.getTradeMatchesForWanted(
          cardId,
          langList,
          fullartOnly: fullartOnly,
          limit: _pageSize,
          offset: offset,
        );
      } else {
        matches = await _userCardService.getTradeMatchesForOwned(
          cardId,
          langList,
          fullartOnly: fullartOnly,
          limit: _pageSize,
          offset: offset,
        );
      }

      final mapped = matches
          .where((m) => cardMap.containsKey(m.cardId))
          .map((m) => (cardMap[m.cardId]!, m))
          .toList();

      if (!mounted) return;
      setState(() {
        if (widget.activeTab == 0) {
          _wantMatches!.addAll(mapped);
          _wantOffset += _pageSize;
          _wantHasMore = matches.length >= _pageSize;
        } else {
          _ownedMatches!.addAll(mapped);
          _ownedOffset += _pageSize;
          _ownedHasMore = matches.length >= _pageSize;
        }
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
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

    final initialConditions = type == 'owned'
        ? _userCardService.getTradeConditions(cardId)
        : <String, Set<String>>{};

    final result = await showDialog<
        ({
          bool wishlisted,
          bool owned,
          Set<String> languages,
          Map<String, Set<String>> conditions,
        })?>(
      context: context,
      builder: (context) => _EditCardDialog(
        card: widget.card,
        initialWishlist: pendingWishlist,
        initialOwned: pendingOwned,
        initialLanguages: pendingLangs,
        initialConditions: initialConditions,
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

      // Sync trade conditions
      if (type == 'owned') {
        final oldConditions = initialConditions;
        final newConditions = result.conditions;
        if (oldConditions.length != newConditions.length ||
            oldConditions.toString() != newConditions.toString()) {
          await _userCardService.setTradeConditions(cardId, newConditions);
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
  final Map<String, Set<String>> initialConditions;
  final String type;
  final bool isEditing;
  final String? warningText;

  const _EditCardDialog({
    required this.card,
    required this.initialWishlist,
    required this.initialOwned,
    required this.initialLanguages,
    required this.initialConditions,
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
  late Map<String, Set<String>> _conditions;

  @override
  void initState() {
    super.initState();
    _wishlisted = widget.initialWishlist;
    _owned = widget.initialOwned;
    _languages = Set.from(widget.initialLanguages);
    _conditions = Map.from(widget.initialConditions);
  }

  String get dialogTitle {
    if (widget.type == 'wishlist') {
      return widget.isEditing ? 'Edit Wishlist' : 'Add to Wishlist';
    }
    return widget.isEditing ? 'Edit Listing' : 'Create a Listing';
  }

  Future<void> _openConditionsPicker() async {
    final result = await Navigator.push<Map<String, Set<String>>>(
      context,
      MaterialPageRoute(
        builder: (_) => TradeConditionPickerScreen(
          listedCard: widget.card,
          initialSelection: _conditions,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _conditions = result);
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
              tradeConditionCount: _conditions.length,
              onConditionsPressed: _openConditionsPicker,
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
                  PhosphorIcon(PhosphorIcons.warning(),
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
        conditions: _conditions,
      ),
    );
  }
}
