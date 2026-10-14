import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:tcgp_trading_app/config/app_colors.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/models/trade_match.dart';
import 'package:tcgp_trading_app/screens/chat_screen.dart';
import 'package:tcgp_trading_app/services/card_service.dart';
import 'package:tcgp_trading_app/collection/collection.dart';
import 'package:tcgp_trading_app/collection/collection_draft.dart';
import 'package:tcgp_trading_app/collection/collection_store.dart';
import 'package:tcgp_trading_app/services/language_filter_service.dart';
import 'package:tcgp_trading_app/utils/activity_utils.dart';
import 'package:tcgp_trading_app/utils/constants.dart';
import 'package:tcgp_trading_app/widgets/shared/card_badge.dart';
import 'package:tcgp_trading_app/widgets/shared/optimized_card_image.dart';
import 'package:tcgp_trading_app/widgets/shared/trade_card_pair.dart';
import 'package:tcgp_trading_app/utils/languages.dart';
import 'package:tcgp_trading_app/widgets/shared/app_dialog.dart';
import 'package:tcgp_trading_app/widgets/card_screen/edit_card_dialog.dart';

class TradeSection extends StatefulWidget {
  final PocketCard card;
  final int activeTab;

  const TradeSection({super.key, required this.card, required this.activeTab});

  @override
  TradeSectionState createState() => TradeSectionState();
}

class TradeSectionState extends State<TradeSection> {
  static const _pageSize = 30;

  final _collectionStore = CollectionStore();
  final _langFilterService = LanguageFilterService();
  bool _isWishlisted = false;
  bool _isListed = false;
  List<(PocketCard, TradeMatch)>? _wantMatches;
  List<(PocketCard, TradeMatch)>? _listingMatches;
  bool _loadingMatches = false;
  bool _loadingMore = false;
  int _wantOffset = 0;
  int _listingOffset = 0;
  bool _wantHasMore = true;
  bool _listingHasMore = true;
  bool _trainersOnly = false;
  bool _myListedOnly = false;
  bool _myWishlistedOnly = false;
  Set<String> _pendingProposals = {};
  final Set<String> _languages = languages.keys.toSet();
  Set<String> _selectedLanguages = {...languages.keys};
  Set<String> _appliedLanguages = {...languages.keys};

  int _fetchRequestId = 0;
  bool _navigatingToMatch = false;

  Collection get _collection => _collectionStore.collection;

  List<TradeCondition> get _tradeConditions =>
      _collection.tradeConditionsOf(widget.card.id);

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
      _listingMatches = null;
      _wantOffset = 0;
      _listingOffset = 0;
      _wantHasMore = true;
      _listingHasMore = true;
    });
    _langFilterService.setSelectedLanguages(_selectedLanguages);
    _fetchMatches();
  }

  InlineSpan _actionSpan(String text, Color color, VoidCallback onTap) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Text(
          text,
          style: TextStyle(fontSize: 12, color: color),
        ),
      ),
    );
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
                                        ' in ${_formatLanguages(card.id, CollectionItemKind.wishlist)}. '),
                                _actionSpan(
                                  'Edit',
                                  AppColors.primary,
                                  () => _showEditCardDialog(CollectionItemKind.wishlist),
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
                                _actionSpan(
                                  'Wishlist now',
                                  AppColors.primary,
                                  _onWantPressed,
                                ),
                              ])
                        : (_isListed
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
                                        ' for trade in ${_formatLanguages(card.id, CollectionItemKind.listing)}. '),
                                if (_tradeConditions.isNotEmpty)
                                  TextSpan(
                                    text:
                                        'Accepting ${_tradeConditions.length} specific ${_tradeConditions.length == 1 ? 'card' : 'cards'}. ',
                                  ),
                                _actionSpan(
                                  'Edit',
                                  AppColors.secondary,
                                  () => _showEditCardDialog(CollectionItemKind.listing),
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
                                _actionSpan(
                                  'List now',
                                  AppColors.secondary,
                                  _onCanTradePressed,
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
                            const TextSpan(text: 'If you list '),
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
                      icon: PhosphorIcon(PhosphorIcons.check(),
                          size: 14, color: Colors.black),
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
                          _listingMatches = null;
                          _wantOffset = 0;
                          _listingOffset = 0;
                          _wantHasMore = true;
                          _listingHasMore = true;
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
                    value: widget.activeTab == 0
                        ? _myListedOnly
                        : _myWishlistedOnly,
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
    var matches = widget.activeTab == 0 ? _wantMatches : _listingMatches;
    final hasMore = widget.activeTab == 0 ? _wantHasMore : _listingHasMore;

    if (_loadingMatches) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (matches == null) return const SizedBox.shrink();

    // Apply trade conditions filter on "I have this card" tab
    if (widget.activeTab == 1 && _tradeConditions.isNotEmpty) {
      final conditionCardIds = {for (final c in _tradeConditions) c.cardId};
      matches =
          matches.where((m) => conditionCardIds.contains(m.$1.id)).toList();
    }

    // Apply client-side filter: "My listings only" / "My wishlist only"
    // Uses language-aware check (same logic as the checkmark icon overlay).
    if (widget.activeTab == 0 && _myListedOnly) {
      matches = matches
          .where((m) =>
              _collection.isListed(m.$1.id, language: m.$2.language))
          .toList();
    } else if (widget.activeTab == 1 && _myWishlistedOnly) {
      matches = matches
          .where((m) =>
              _collection.isWishlisted(m.$1.id, language: m.$2.language))
          .toList();
    }

    if (matches.isEmpty && !hasMore) {
      final hintText = widget.activeTab == 0
          ? 'Try wishlisting this card in more languages or using the All languages filter above for more trade options.'
          : 'Try listing this card for trade or using the All languages filter above for more trade options.';

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 6),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'No trade options found',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  hintText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white30,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Hoist to a non-nullable local so the itemBuilder closure doesn't
    // lose null-promotion across the capture boundary.
    final List<(PocketCard, TradeMatch)> visibleMatches = matches;
    final itemCount = visibleMatches.length + (_loadingMore ? 1 : 0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index >= visibleMatches.length) {
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

          final (matchCard, tradeMatch) = visibleMatches[index];
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
                if (_collection.isWishlisted(
                      matchCard.id,
                      language: tradeMatch.language,
                    ) ||
                    _collection.isListed(
                      matchCard.id,
                      language: tradeMatch.language,
                    ))
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: CardBadge(
                      type: _collection.isListed(
                        matchCard.id,
                        language: tradeMatch.language,
                      )
                          ? CardBadgeType.matchListing
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
    if (_navigatingToMatch) return;
    _navigatingToMatch = true;

    // Determine languages for the trade message
    final String offerLanguage;
    final String receiveLanguage;
    if (widget.activeTab == 0) {
      // "I want this card" tab: offerCard=matchCard, receiveCard=contextCard
      offerLanguage = tradeMatch.language;
      final contextLangs =
          _collection.languagesOf(widget.card.id, CollectionItemKind.wishlist);
      receiveLanguage = contextLangs.isNotEmpty ? contextLangs.first : '';
    } else {
      // "I have this card" tab: offerCard=contextCard, receiveCard=matchCard
      final contextLangs =
          _collection.languagesOf(widget.card.id, CollectionItemKind.listing);
      offerLanguage = contextLangs.isNotEmpty ? contextLangs.first : '';
      receiveLanguage = tradeMatch.language;
    }

    try {
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

      if (!mounted) return;
      final proposals = await _collectionStore.getMyPendingProposals();
      if (!mounted) return;
      setState(() => _pendingProposals = proposals);
    } finally {
      _navigatingToMatch = false;
    }
  }

  void _onMatchTapped(PocketCard matchCard, TradeMatch tradeMatch) {
    if (_navigatingToMatch) return;
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
        ? !_collection.isListed(
            matchCard.id,
            language: tradeMatch.language,
          )
        : !_collection.isWishlisted(
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
          _collection.languagesOf(widget.card.id, CollectionItemKind.wishlist);
      receiveLanguage = contextLangs.isNotEmpty ? contextLangs.first : '';
    } else {
      // "I have this card" → user sends contextCard, receives matchCard
      sendCard = widget.card;
      receiveCard = matchCard;
      final contextLangs =
          _collection.languagesOf(widget.card.id, CollectionItemKind.listing);
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

  String _formatLanguages(String cardId, CollectionItemKind kind) {
    final langs = _collection.languagesOf(cardId, kind);

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
    _collectionStore.load().then((_) {
      if (!mounted) return;
      setState(() {
        _isWishlisted = _collection.isWishlisted(widget.card.id);
        _isListed = _collection.isListed(widget.card.id);
      });
      _fetchMatches();
    }).catchError((e) {
      debugPrint('Failed to load user cards in trade section: $e');
    });
  }

  void _refreshState() {
    setState(() {
      _isWishlisted = _collection.isWishlisted(widget.card.id);
      _isListed = _collection.isListed(widget.card.id);
      _wantMatches = null;
      _listingMatches = null;
      _wantOffset = 0;
      _listingOffset = 0;
      _wantHasMore = true;
      _listingHasMore = true;
    });
    _fetchMatches();
  }

  Future<void> _fetchMatches() async {
    final cardId = widget.card.id;
    final wantNeeded = _wantMatches == null;
    final listingNeeded = _listingMatches == null;
    if (!wantNeeded && !listingNeeded) return;

    final requestId = ++_fetchRequestId;
    setState(() => _loadingMatches = true);

    try {
      final cardMap = CardService().getCardMap();
      final futures = <Future>[];

      futures.add(_collectionStore.getMyPendingProposals().then((proposals) {
        if (requestId != _fetchRequestId) return;
        _pendingProposals = proposals;
      }));

      final langList = _appliedLanguages.toList();
      final fullartOnly = _trainersOnly && _isFullArtSupporter;

      if (wantNeeded) {
        futures.add(_collectionStore
            .getTradeMatchesForWanted(cardId, langList,
                fullartOnly: fullartOnly, limit: _pageSize, offset: 0)
            .then((matches) {
          if (requestId != _fetchRequestId) return;
          final mapped = matches
              .where((m) => cardMap.containsKey(m.cardId))
              .map((m) => (cardMap[m.cardId]!, m))
              .toList();
          _wantMatches = mapped;
          _wantOffset = _pageSize;
          _wantHasMore = matches.length >= _pageSize;
        }));
      }

      if (listingNeeded) {
        futures.add(_collectionStore
            .getTradeMatchesForListing(cardId, langList,
                fullartOnly: fullartOnly, limit: _pageSize, offset: 0)
            .then((matches) {
          if (requestId != _fetchRequestId) return;
          final mapped = matches
              .where((m) => cardMap.containsKey(m.cardId))
              .map((m) => (cardMap[m.cardId]!, m))
              .toList();
          _listingMatches = mapped;
          _listingOffset = _pageSize;
          _listingHasMore = matches.length >= _pageSize;
        }));
      }

      await Future.wait(futures);
    } catch (e) {
      debugPrint('Failed to fetch trade matches: $e');
      _wantMatches ??= [];
      _listingMatches ??= [];
    }

    if (!mounted || requestId != _fetchRequestId) return;
    setState(() => _loadingMatches = false);
  }

  void loadMore() {
    if (_loadingMatches || _loadingMore) return;
    final hasMore = widget.activeTab == 0 ? _wantHasMore : _listingHasMore;
    final matches = widget.activeTab == 0 ? _wantMatches : _listingMatches;
    if (!hasMore || matches == null) return;
    _loadMoreMatches();
  }

  Future<void> _loadMoreMatches() async {
    if (_loadingMore || _navigatingToMatch) return;
    setState(() => _loadingMore = true);

    try {
      final cardId = widget.card.id;
      final cardMap = CardService().getCardMap();
      final langList = _appliedLanguages.toList();
      final fullartOnly = _trainersOnly && _isFullArtSupporter;
      final offset = widget.activeTab == 0 ? _wantOffset : _listingOffset;

      final List<TradeMatch> matches;
      if (widget.activeTab == 0) {
        matches = await _collectionStore.getTradeMatchesForWanted(
          cardId,
          langList,
          fullartOnly: fullartOnly,
          limit: _pageSize,
          offset: offset,
        );
      } else {
        matches = await _collectionStore.getTradeMatchesForListing(
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
          if (_wantMatches == null) {
            _wantMatches = mapped;
          } else {
            _wantMatches!.addAll(mapped);
          }
          _wantOffset += _pageSize;
          _wantHasMore = matches.length >= _pageSize;
        } else {
          if (_listingMatches == null) {
            _listingMatches = mapped;
          } else {
            _listingMatches!.addAll(mapped);
          }
          _listingOffset += _pageSize;
          _listingHasMore = matches.length >= _pageSize;
        }
        _loadingMore = false;
      });
    } catch (e) {
      debugPrint('Failed to load more trade matches: $e');
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _onWantPressed() async {
    await _showEditCardDialog(CollectionItemKind.wishlist);
  }

  Future<void> _onCanTradePressed() async {
    await _showEditCardDialog(CollectionItemKind.listing);
  }

  Future<void> _showEditCardDialog(CollectionItemKind kind) async {
    final cardId = widget.card.id;
    final saved = _collection.stateOf(cardId);
    final isWishlist = kind == CollectionItemKind.wishlist;
    final isEditing = isWishlist ? saved is Wishlisted : saved is Listed;

    // The dialog opens with the card already turned on as [kind].
    var draft = CollectionDraft(_collection);
    if (!isEditing) {
      draft = isWishlist
          ? draft.toggleWishlist(cardId)
          : draft.toggleListing(cardId);
    }

    final hasOppositeEntry = isWishlist ? saved is Listed : saved is Wishlisted;
    final warningText = hasOppositeEntry
        ? isWishlist
            ? 'You have already listed this card for trade. Adding it to your wishlist will remove your listing.'
            : 'You have already wishlisted this card. Creating a listing will remove it from your wishlist.'
        : null;

    final savedChanges = await showDialog<bool>(
      context: context,
      builder: (context) => EditCardDialog(
        card: widget.card,
        draft: draft,
        kind: kind,
        isEditing: isEditing,
        warningText: warningText,
        save: _collectionStore.commit,
      ),
    );

    if (savedChanges != true || !mounted) return;
    _refreshState();
  }
}
