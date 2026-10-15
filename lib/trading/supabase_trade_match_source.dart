import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/trading/trade_match.dart';
import 'package:tcgp_trading_app/trading/trade_match_source.dart';
import 'package:tcgp_trading_app/utils/async_utils.dart';

/// Reads trade matches and pending proposals through the RPCs in
/// supabase/trade_matches_schema.sql, which apply every matching rule.
class SupabaseTradeMatchSource implements TradeMatchSource {
  final SupabaseClient _client;

  SupabaseTradeMatchSource([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  @override
  Future<List<TradeMatchRow>> fetchPage(
    PocketCard card,
    TradeDirection direction,
    TradeMatchFilter filter, {
    required int offset,
    required int limit,
  }) async {
    if (_client.auth.currentUser == null) return [];
    final rows = await withTimeout(_client.rpc('get_trade_matches', params: {
      'p_card_id': card.id,
      'p_direction': direction.name,
      'p_languages': filter.languages.toList(),
      'p_fullart_only': filter.fullArtOnly,
      'p_only_mine': filter.onlyMine,
      'p_limit': limit,
      'p_offset': offset,
    }));
    return [for (final r in rows as List) _rowFromJson(r as Map<String, dynamic>)];
  }

  @override
  Future<Set<ProposalKey>> pendingProposals() async {
    if (_client.auth.currentUser == null) return {};
    final rows = await withTimeout(_client.rpc('get_my_pending_proposals'));
    return {
      for (final r in rows as List)
        (
          otherUserId: r['other_user_id'] as String,
          sendCardId: r['offer_card_id'] as String,
          receiveCardId: r['receive_card_id'] as String,
        ),
    };
  }

  static TradeMatchRow _rowFromJson(Map<String, dynamic> json) => TradeMatchRow(
        userId: json['user_id'] as String,
        playerName: json['player_name'] as String? ?? 'Unknown',
        friendId: json['friend_id'] as String? ?? '',
        icon: json['icon'] as String?,
        lastActiveAt: DateTime.tryParse(json['last_active_at'] as String? ?? ''),
        sendCardId: json['send_card_id'] as String,
        sendLanguage: json['send_language'] as String,
        receiveCardId: json['receive_card_id'] as String,
        receiveLanguage: json['receive_language'] as String,
        isPerfect: json['is_perfect'] as bool? ?? false,
      );
}
