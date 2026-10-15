import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:tcgp_trading_app/auth/profile_service.dart';
import 'package:tcgp_trading_app/config/app_colors.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/screens/chat_screen.dart';
import 'package:tcgp_trading_app/collection/collection.dart';
import 'package:tcgp_trading_app/collection/collection_draft.dart';
import 'package:tcgp_trading_app/collection/collection_store.dart';
import 'package:tcgp_trading_app/services/language_filter_service.dart';
import 'package:tcgp_trading_app/trading/trade_match.dart';
import 'package:tcgp_trading_app/trading/trade_match_feed.dart';
import 'package:tcgp_trading_app/utils/activity_utils.dart';
import 'package:tcgp_trading_app/utils/constants.dart';
import 'package:tcgp_trading_app/widgets/shared/card_badge.dart';
import 'package:tcgp_trading_app/widgets/shared/optimized_card_image.dart';
import 'package:tcgp_trading_app/widgets/shared/trade_card_pair.dart';
import 'package:tcgp_trading_app/utils/languages.dart';
import 'package:tcgp_trading_app/widgets/shared/app_dialog.dart';
import 'package:tcgp_trading_app/widgets/card_screen/edit_card_dialog.dart';

/// The copy that differs between the two directions of a card's trade
/// matches.
class _DirectionText {
  /// What the viewed card is in the user's collection for this direction to
  /// be a perfect match: a wishlist entry when receiving it, a listing when
  /// sending it.
  final CollectionItemKind viewedKind;
  final String intro;
  final String onlyMineLabel;
  final String emptyHint;

  const _DirectionText({
    required this.viewedKind,
    required this.intro,
    required this.onlyMineLabel,
    required this.emptyHint,
  });

  static _DirectionText of(TradeDirection direction) => switch (direction) {
        TradeDirection.receiving => const _DirectionText(
            viewedKind: CollectionItemKind.wishlist,
            intro: 'If you want {card}, these are the cards you could offer '
                'for it.',
            onlyMineLabel: 'Show only cards I have listed',
            emptyHint: 'Nobody has listed this card in your selected '
                'languages yet. Try All languages, or wishlist it so other '
                'players can find you.',
          ),
        TradeDirection.sending => const _DirectionText(
            viewedKind: CollectionItemKind.listing,
            intro: 'If you trade away {card}, these are the cards you could '
                'ask for in return.',
            onlyMineLabel: 'Show only cards I have wishlisted',
            emptyHint: 'Nobody has wishlisted this card in your selected '
                'languages yet. Try All languages, or list it so other '
                'players can find you.',
          ),
      };
}

/// A view of one [TradeMatchFeed]: the viewed card's collection state, the
/// filters and the grid of trade matches.
class TradeSection extends StatefulWidget {
  final PocketCard card;
  final TradeMatchFeed feed;

  /// Applies a filter change shared by both directions (card languages,
  /// full-art only) to every feed on the screen.
  final void Function(TradeMatchFilter Function(TradeMatchFilter) update)
      onSharedFilterChanged;

  /// Called after the user saved a change to their collection, which can
  /// change the matches of every feed.
  final VoidCallback onCollectionSaved;

  const TradeSection({
    super.key,
    required this.card,
    required this.feed,
    required this.onSharedFilterChanged,
    required this.onCollectionSaved,
  });

  @override
  State<TradeSection> createState() => _TradeSectionState();
}

class _TradeSectionState extends State<TradeSection> {
  final _collectionStore = CollectionStore();
  final _langFilterService = LanguageFilterService();
  final Set<String> _languages = languages.keys.toSet();

  /// The language chips selected, applied to the feeds on "Apply".
  late Set<String> _selectedLanguages = {...widget.feed.filter.languages};

  bool _navigatingToMatch = false;

  Collection get _collection => _collectionStore.collection;

  TradeMatchFeed get _feed => widget.feed;

  _DirectionText get _text => _DirectionText.of(_feed.direction);

  bool get _isFullArtSupporter =>
      widget.card.rarity == '☆☆' &&
      widget.card.cardType.toLowerCase() == 'supporter';

  @override
  void initState() {
    super.initState();
    _collectionStore.load().catchError((Object e) {
      debugPrint('Failed to load user cards in trade section: $e');
    });
  }

  void _applyLanguageFilter() {
    final selected = {..._selectedLanguages};
    _langFilterService.setSelectedLanguages(selected);
    widget.onSharedFilterChanged((f) => f.copyWith(languages: selected));
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
    return ListenableBuilder(
      listenable: Listenable.merge([_feed, _collectionStore]),
      builder: (context, _) => _buildSection(),
    );
  }

  Widget _buildSection() {
    final card = widget.card;
    final cardName = TextSpan(
      text: card.name,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.white70,
      ),
    );
    final introParts = _text.intro.split('{card}');
    final appliedLanguages = _feed.filter.languages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBanner(_collectionStateSpans(cardName)),
        _infoBanner([
          TextSpan(text: introParts.first),
          cardName,
          TextSpan(text: introParts.last),
        ]),
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
                          setState(() => _selectedLanguages =
                              selected ? {..._languages} : {});
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
                              setState(() => _selectedLanguages = updated);
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
              if (_selectedLanguages.length != appliedLanguages.length ||
                  !_selectedLanguages.containsAll(appliedLanguages))
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
          _toggle(
            label: 'Full Art Supporters only',
            value: _feed.filter.fullArtOnly,
            onChanged: (value) => widget.onSharedFilterChanged(
                (f) => f.copyWith(fullArtOnly: value)),
          ),
        _toggle(
          label: _text.onlyMineLabel,
          value: _feed.filter.onlyMine,
          onChanged: (value) =>
              _feed.setFilter(_feed.filter.copyWith(onlyMine: value)),
        ),
        _buildMatchGrid(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _infoBanner(List<InlineSpan> spans) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(6, 10, 6, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          PhosphorIcon(PhosphorIcons.info(), size: 16, color: Colors.white38),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 12, color: Colors.white54),
                children: spans,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Whether the user wishlisted (receiving) or listed (sending) the viewed
  /// card, with a shortcut to change it.
  List<InlineSpan> _collectionStateSpans(InlineSpan cardName) {
    final kind = _text.viewedKind;
    final cardId = widget.card.id;
    final conditions = _collection.tradeConditionsOf(cardId);
    void edit() => _showEditCardDialog(kind);
    return switch (kind) {
      CollectionItemKind.wishlist => _collection.isWishlisted(cardId)
          ? [
              const TextSpan(text: 'You have wishlisted '),
              cardName,
              TextSpan(text: ' in ${_formatLanguages(cardId, kind)}. '),
              _actionSpan('Edit', AppColors.primary, edit),
            ]
          : [
              const TextSpan(text: 'You have not wishlisted '),
              cardName,
              const TextSpan(text: ' yet. '),
              _actionSpan('Wishlist now', AppColors.primary, edit),
            ],
      CollectionItemKind.listing => _collection.isListed(cardId)
          ? [
              const TextSpan(text: 'You have listed '),
              cardName,
              TextSpan(
                  text: ' for trade in ${_formatLanguages(cardId, kind)}. '),
              if (conditions.isNotEmpty)
                TextSpan(
                  text: 'Accepting ${conditions.length} specific '
                      '${conditions.length == 1 ? 'card' : 'cards'}. ',
                ),
              _actionSpan('Edit', AppColors.secondary, edit),
            ]
          : [
              const TextSpan(text: 'You have not listed '),
              cardName,
              const TextSpan(text: ' for trade yet. '),
              _actionSpan('List now', AppColors.secondary, edit),
            ],
    };
  }

  Widget _toggle({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 6, 0),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(width: 6),
          SizedBox(
            height: 32,
            child: FittedBox(
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeColor: AppColors.primary,
                activeTrackColor: AppColors.primary.withOpacity(0.4),
                inactiveThumbColor: Colors.white38,
                inactiveTrackColor: Colors.white10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchGrid() {
    final state = _feed.state;

    if (state.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.matches.isEmpty && state.error != null) {
      return _RetryRow(onRetry: _feed.load);
    }

    if (state.matches.isEmpty && !state.hasMore) {
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
                  _text.emptyHint,
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

    final matches = state.matches;
    final itemCount = matches.length + (state.isLoadingMore ? 1 : 0);

    return Column(
      children: [
        Padding(
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
              if (index >= matches.length) {
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
              return _buildMatchTile(matches[index]);
            },
          ),
        ),
        if (state.error != null) _RetryRow(onRetry: _feed.loadMore),
      ],
    );
  }

  Widget _buildMatchTile(TradeMatch match) {
    final other = match.other;
    final isListed =
        _collection.isListed(other.card.id, language: other.language);
    final isWishlisted =
        _collection.isWishlisted(other.card.id, language: other.language);
    return GestureDetector(
      onTap: () => _onMatchTapped(match),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: OptimizedCardImage(
              imageUrl: other.card.imageUrl,
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
            child: _LanguageTag(other.language),
          ),
          if (isListed || isWishlisted)
            Positioned(
              bottom: 4,
              right: 4,
              child: CardBadge(
                type: isListed
                    ? CardBadgeType.matchListing
                    : CardBadgeType.matchWishlisted,
              ),
            ),
          if (match.hasPendingProposal)
            const Positioned(
              bottom: 4,
              left: 4,
              child: CardBadge(type: CardBadgeType.pendingTrade),
            ),
        ],
      ),
    );
  }

  Future<void> _navigateToChat(TradeMatch match) async {
    if (_navigatingToMatch) return;
    _navigatingToMatch = true;
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatScreen.forTradeMatch(match)),
      );
      if (!mounted) return;
      await _feed.refreshProposals();
    } finally {
      _navigatingToMatch = false;
    }
  }

  void _onMatchTapped(TradeMatch match) {
    if (_navigatingToMatch) return;
    if (match.hasPendingProposal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'You already sent a trade proposal to this user for this card'),
        ),
      );
      return;
    }

    final send = match.send;
    final receive = match.receive;

    showAppDialog<void>(
      context: context,
      title: 'Trade Preview',
      centerContent: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TradeCardPair(
            leftCard: send.card,
            rightCard: receive.card,
            leftTopLabel: 'You send',
            rightTopLabel: '${match.playerName} sends',
            leftBottomLabel: send.card.name,
            rightBottomLabel: receive.card.name,
            leftLanguage: send.language,
            rightLanguage: receive.language,
            rightActivityColor: activityColor(match.lastActiveAt),
          ),
          // A partial match: say what the user's collection is missing.
          if (!_collection.isListed(send.card.id, language: send.language))
            _PartialMatchWarning(
              before: 'You have not listed ',
              side: send,
              after: ' for trade',
            ),
          if (!_collection.isWishlisted(receive.card.id,
              language: receive.language))
            _PartialMatchWarning(
              before: 'You have not added ',
              side: receive,
              after: ' to your wishlist',
            ),
        ],
      ),
      primaryText: 'Continue',
      onPrimaryAction: () => _navigateToChat(match),
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

  bool _openingEditCardDialog = false;

  Future<void> _showEditCardDialog(CollectionItemKind kind) async {
    // One dialog at a time, even when tapped again while the preferred
    // language loads.
    if (_openingEditCardDialog) return;
    _openingEditCardDialog = true;
    try {
      await _openEditCardDialog(kind);
    } finally {
      _openingEditCardDialog = false;
    }
  }

  Future<void> _openEditCardDialog(CollectionItemKind kind) async {
    final preferredLanguage = await ProfileService().getPreferredLanguage();
    if (!mounted) return;
    final cardId = widget.card.id;
    final saved = _collection.stateOf(cardId);
    final isWishlist = kind == CollectionItemKind.wishlist;
    final isEditing = isWishlist ? saved is Wishlisted : saved is Listed;

    // The dialog opens with the card already turned on as [kind].
    var draft =
        CollectionDraft(_collection, preferredLanguage: preferredLanguage);
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
    widget.onCollectionSaved();
  }
}

/// A card language code on a dark tag, as on card thumbnails.
class _LanguageTag extends StatelessWidget {
  final String language;

  const _LanguageTag(this.language);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(UIConstants.buttonOpacity),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        language,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Colors.white70,
        ),
      ),
    );
  }
}

/// One thing the user's collection doesn't allow yet in a partial match,
/// e.g. "You have not listed Pikachu [ENG] for trade".
class _PartialMatchWarning extends StatelessWidget {
  final String before;
  final TradeSide side;
  final String after;

  const _PartialMatchWarning({
    required this.before,
    required this.side,
    required this.after,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          PhosphorIcon(PhosphorIcons.warning(), size: 16, color: Colors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 12, color: Colors.amber),
                children: [
                  TextSpan(text: before),
                  TextSpan(
                    text: '${side.card.name} ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: _LanguageTag(side.language),
                  ),
                  TextSpan(text: after),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown in place of, or below, the matches when a fetch failed.
class _RetryRow extends StatelessWidget {
  final VoidCallback onRetry;

  const _RetryRow({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(6, 16, 6, 0),
        padding: const EdgeInsets.only(left: 12, right: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E24),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            PhosphorIcon(PhosphorIcons.warningCircle(),
                size: 16, color: Colors.white54),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                "Couldn't load trade options",
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ),
            TextButton.icon(
              onPressed: onRetry,
              icon: PhosphorIcon(PhosphorIcons.arrowClockwise(),
                  size: 14, color: AppColors.primary),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                minimumSize: const Size(44, 44),
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
