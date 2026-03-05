import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tcgp_trading_app/models/card.dart';

class CardService {
  static const _cardsUrl =
      'https://cdn.jsdelivr.net/npm/pokemon-tcg-pocket-database/dist/cards.json';
  static const _cacheKey = 'cached_cards_json';

  static final CardService _instance = CardService._();
  factory CardService() => _instance;
  CardService._();

  List<PocketCard>? _cards;

  /// Load cards from CDN, falling back to cache if offline.
  Future<List<PocketCard>> getAllCards() async {
    if (_cards != null) return _cards!;

    // Try fetching from CDN
    try {
      final response = await http
          .get(Uri.parse(_cardsUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final jsonString = response.body;
        _cards = _parseCards(jsonString);
        // Cache for offline use
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKey, jsonString);
        return _cards!;
      }
    } catch (_) {
      // Fall through to cache
    }

    // Fallback: load from cache
    final prefs = await SharedPreferences.getInstance();
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

  /// Get a single card by set and number.
  Future<PocketCard?> getCard(String set, int number) async {
    final all = await getAllCards();
    try {
      return all.firstWhere((c) => c.set == set && c.number == number);
    } catch (_) {
      return null;
    }
  }

  /// Clear in-memory cache (e.g. for pull-to-refresh).
  void clearCache() {
    _cards = null;
  }
}
