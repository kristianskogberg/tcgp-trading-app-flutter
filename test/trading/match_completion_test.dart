import 'package:flutter_test/flutter_test.dart';
import 'package:tcgp_trading_app/collection/collection.dart';
import 'package:tcgp_trading_app/collection/collection_draft.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/trading/match_completion.dart';
import 'package:tcgp_trading_app/trading/trade_match.dart';

PocketCard _card(String id) => PocketCard(
      id: id,
      name: 'Card $id',
      rarity: '◊',
      pack: '',
      imageUrl: '',
      type: 'Pokemon',
      cardType: '',
    );

const _sent = 'A1-001';
const _received = 'A1-002';

TradeMatch _match(
        {String sendLanguage = 'JPN', String receiveLanguage = 'FRA'}) =>
    TradeMatch(
      userId: 'bob',
      playerName: 'Bob',
      friendId: '',
      send: TradeSide(_card(_sent), sendLanguage),
      receive: TradeSide(_card(_received), receiveLanguage),
      direction: TradeDirection.receiving,
      isPerfect: false,
    );

MatchCompletion _completion(
  Collection collection, {
  TradeMatch? match,
  String preferredLanguage = 'ENG',
}) =>
    MatchCompletion.of(
      match ?? _match(),
      collection,
      preferredLanguage: preferredLanguage,
    );

void main() {
  group('the card the user sends', () {
    test('offers a listing in the sent language when it is not listed', () {
      final listing = _completion(Collection()).listing;
      expect(listing, isNotNull);
      expect(listing!.card.id, _sent);
      expect(listing.language, 'JPN');
    });

    test('offers nothing when it is already listed', () {
      final collection = Collection(listings: [
        Listing(cardId: _sent, language: 'JPN'),
      ]);
      expect(_completion(collection).listing, isNull);
    });

    test(
        'offers nothing when it is wishlisted, as listing it would remove '
        'the wishlist entry', () {
      final collection = Collection(wishlist: [
        WishlistEntry(cardId: _sent, languages: {'ANY'}),
      ]);
      expect(_completion(collection).listing, isNull);
    });

    test(
        'offers a listing in the preferred language when the other player '
        'accepts any language', () {
      final listing = _completion(
        Collection(),
        match: _match(sendLanguage: 'ANY'),
        preferredLanguage: 'KOR',
      ).listing;
      expect(listing!.language, 'KOR');
    });
  });

  group('the card the user receives', () {
    test(
        'offers a wishlist entry in the received language when it is not '
        'wishlisted', () {
      final entry = _completion(Collection()).wishlistEntry;
      expect(entry, isNotNull);
      expect(entry!.card.id, _received);
      expect(entry.language, 'FRA');
    });

    test('offers nothing when it is already wishlisted', () {
      final collection = Collection(wishlist: [
        WishlistEntry(cardId: _received, languages: {'FRA'}),
      ]);
      expect(_completion(collection).wishlistEntry, isNull);
    });

    test(
        'offers nothing when it is listed, as wishlisting it would remove '
        'the listing', () {
      final collection = Collection(listings: [
        Listing(cardId: _received, language: 'FRA'),
      ]);
      expect(_completion(collection).wishlistEntry, isNull);
    });
  });

  group('adding to a Collection draft', () {
    test('adds the chosen listing and wishlist entry', () {
      final draft = _completion(Collection()).addTo(
        CollectionDraft(Collection()),
        addListing: true,
        addWishlistEntry: true,
      );
      expect(draft.changes, {
        _sent: Listed('JPN'),
        _received: Wishlisted({'FRA'}),
      });
    });

    test('adds nothing the user unchecked', () {
      final draft = _completion(Collection()).addTo(
        CollectionDraft(Collection()),
        addListing: false,
        addWishlistEntry: false,
      );
      expect(draft.hasChanges, isFalse);
    });
  });

  group('the trade proposal', () {
    test(
        'sends the listed language once the card sent in any language is '
        'listed', () {
      final completion = _completion(
        Collection(),
        match: _match(sendLanguage: 'ANY'),
        preferredLanguage: 'KOR',
      );
      expect(completion.proposal(listingAdded: true).send.language, 'KOR');
      expect(completion.proposal(listingAdded: false).send.language, 'ANY');
    });
  });
}
