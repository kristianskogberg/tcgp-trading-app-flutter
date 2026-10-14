import 'package:flutter/foundation.dart';
import 'package:tcgp_trading_app/collection/collection.dart';
import 'package:tcgp_trading_app/utils/languages.dart';

/// The preferred language used until users can choose their own.
const fallbackPreferredLanguage = 'ENG';

/// The language choices a card allows.
enum LanguageChoices {
  /// "Any language", or one or more specific languages (a wishlist entry).
  anyOrSeveral,

  /// Exactly one specific language (a listing).
  oneSpecific,
}

/// Unsaved edits to a [Collection].
///
/// Every intent returns a new draft and corrects input that would break a
/// collection rule instead of rejecting it:
/// 1. A card is either a wishlist entry or a listing, never both.
/// 2. A wishlist entry has "any language" or specific languages, never both.
/// 3. A listing has exactly one specific language.
/// 4. A new wishlist entry starts as "any language"; a new listing starts in
///    the preferred language.
/// 5. Wishlist to listing keeps the first specific language, or the preferred
///    language if there is none. Listing to wishlist keeps the listing's
///    language.
/// 6. Turning a card off and back on restores its saved state.
/// 7. Only a listing has trade conditions; a language change keeps them.
///
/// See docs/adr/0001-collection-writes-via-atomic-rpc.md.
@immutable
class CollectionDraft {
  final Collection _saved;
  final String preferredLanguage;

  /// The desired state of each card that differs from [_saved].
  final Map<String, CardState> _changes;

  const CollectionDraft(Collection saved, {String? preferredLanguage})
      : this._(saved, preferredLanguage ?? fallbackPreferredLanguage, const {});

  const CollectionDraft._(this._saved, this.preferredLanguage, this._changes);

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  CardState stateOf(String cardId) =>
      _changes[cardId] ?? _saved.stateOf(cardId);

  /// The language choices [cardId] allows, or null if it isn't in the
  /// collection.
  LanguageChoices? languageChoicesFor(String cardId) =>
      switch (stateOf(cardId)) {
        NotInCollection() => null,
        Wishlisted() => LanguageChoices.anyOrSeveral,
        Listed() => LanguageChoices.oneSpecific,
      };

  /// Whether [cardId] is a trade condition on any listing in this draft.
  bool isTradeConditionTarget(String cardId) =>
      _saved.withChanges(_changes).isTradeConditionTarget(cardId);

  bool get hasChanges => _changes.isNotEmpty;

  /// The desired state of each changed card.
  Map<String, CardState> get changes => Map.unmodifiable(_changes);

  // ---------------------------------------------------------------------------
  // Intents
  // ---------------------------------------------------------------------------

  /// Turns [cardId]'s wishlist entry on or off.
  CollectionDraft toggleWishlist(String cardId) {
    final current = stateOf(cardId);
    if (current is Wishlisted) return _with(cardId, const NotInCollection());
    if (_saved.stateOf(cardId) case final Wishlisted saved) {
      return _with(cardId, saved);
    }
    return _with(
      cardId,
      switch (current) {
        Listed(:final language) => Wishlisted({language}),
        _ => Wishlisted({anyLanguage}),
      },
    );
  }

  /// Turns [cardId]'s listing on or off.
  CollectionDraft toggleListing(String cardId) {
    final current = stateOf(cardId);
    if (current is Listed) return _with(cardId, const NotInCollection());
    if (_saved.stateOf(cardId) case final Listed saved) {
      return _with(cardId, saved);
    }
    return _with(
      cardId,
      switch (current) {
        Wishlisted(:final languages) =>
          Listed(_firstSpecific(languages) ?? preferredLanguage),
        _ => Listed(preferredLanguage),
      },
    );
  }

  /// Sets [cardId]'s languages. A listing takes the newly chosen specific
  /// language; a wishlist entry keeps either "any language", if it was just
  /// chosen, or the specific languages. Does nothing for a card that isn't in
  /// the collection or when no usable language is given.
  CollectionDraft setLanguages(String cardId, Set<String> languages) {
    final current = stateOf(cardId);
    switch (current) {
      case NotInCollection():
        return this;
      case Wishlisted(languages: final before):
        final specific = languages.difference({anyLanguage});
        final anyJustChosen =
            languages.contains(anyLanguage) && !before.contains(anyLanguage);
        if (anyJustChosen || (specific.isEmpty && languages.isNotEmpty)) {
          return _with(cardId, Wishlisted({anyLanguage}));
        }
        if (specific.isEmpty) return this;
        return _with(cardId, Wishlisted(specific));
      case Listed(:final language, :final tradeConditions):
        final chosen =
            _firstSpecific(languages.difference({language})) ??
                (languages.contains(language) ? language : null);
        if (chosen == null) return this;
        return _with(cardId, Listed(chosen, tradeConditions: tradeConditions));
    }
  }

  /// Replaces the trade conditions on [cardId]'s listing. Does nothing for a
  /// card that isn't a listing.
  CollectionDraft setTradeConditions(
    String cardId,
    List<TradeCondition> tradeConditions,
  ) {
    final current = stateOf(cardId);
    if (current is! Listed) return this;
    return _with(
      cardId,
      Listed(current.language, tradeConditions: tradeConditions),
    );
  }

  /// Drops every change.
  CollectionDraft discard() =>
      CollectionDraft._(_saved, preferredLanguage, const {});

  // ---------------------------------------------------------------------------

  CollectionDraft _with(String cardId, CardState state) {
    final changes = {..._changes};
    if (state == _saved.stateOf(cardId)) {
      changes.remove(cardId);
    } else {
      changes[cardId] = state;
    }
    return CollectionDraft._(_saved, preferredLanguage, changes);
  }

  /// The first specific language of [candidates] in the app's language order.
  static String? _firstSpecific(Set<String> candidates) {
    final specific = candidates.difference({anyLanguage});
    if (specific.isEmpty) return null;
    final order = languages.keys.toList();
    int rank(String l) {
      final i = order.indexOf(l);
      return i == -1 ? order.length : i;
    }

    return specific.reduce((a, b) => rank(b) < rank(a) ? b : a);
  }
}
