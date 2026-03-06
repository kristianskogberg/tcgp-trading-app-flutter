import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tcgp_trading_app/models/card.dart';

class CardService {
  static const _cardsUrl =
      'https://raw.githubusercontent.com/chase-manning/pokemon-tcg-pocket-cards/refs/heads/main/v4.json';
  static const _cacheKey = 'cached_cards_json';
  static const _etagKey = 'cached_cards_etag';

  static final CardService _instance = CardService._();
  factory CardService() => _instance;
  CardService._();

  List<PocketCard>? _cards;
  Map<String, PocketCard>? _cardMap;

  /// Load cards from GitHub, using ETag for conditional requests.
  /// Falls back to cache if offline.
  Future<List<PocketCard>> getAllCards() async {
    if (_cards != null) return _cards!;

    final prefs = await SharedPreferences.getInstance();
    final cachedEtag = prefs.getString(_etagKey);

    try {
      final headers = <String, String>{};
      if (cachedEtag != null) {
        headers['If-None-Match'] = cachedEtag;
      }

      final response = await http
          .get(Uri.parse(_cardsUrl), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonString = response.body;
        _cards = _parseCards(jsonString);
        // Cache JSON and ETag
        await prefs.setString(_cacheKey, jsonString);
        final etag = response.headers['etag'];
        if (etag != null) {
          await prefs.setString(_etagKey, etag);
        }
        return _cards!;
      }

      if (response.statusCode == 304) {
        // Not modified — use cached data
        final cached = prefs.getString(_cacheKey);
        if (cached != null) {
          _cards = _parseCards(cached);
          return _cards!;
        }
      }
    } catch (_) {
      // Fall through to cache
    }

    // Fallback: load from cache
    final cached = prefs.getString(_cacheKey);
    if (cached != null) {
      _cards = _parseCards(cached);
      return _cards!;
    }

    return [];
  }

  List<PocketCard> _parseCards(String jsonString) {
    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((e) => PocketCard.fromJson(e)).toList();
  }

  /// Get cards filtered by set.
  Future<List<PocketCard>> getCardsBySet(String set) async {
    final all = await getAllCards();
    return all.where((c) => c.set == set).toList();
  }

  /// Get a single card by id.
  Future<PocketCard?> getCard(String id) async {
    final all = await getAllCards();
    try {
      return all.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Map<String, PocketCard> getCardMap() {
    if (_cardMap != null) return _cardMap!;
    if (_cards == null) return {};
    _cardMap = {for (final c in _cards!) c.id: c};
    return _cardMap!;
  }

  /// Clear in-memory cache (e.g. for pull-to-refresh).
  void clearCache() {
    _cards = null;
    _cardMap = null;
  }
}
