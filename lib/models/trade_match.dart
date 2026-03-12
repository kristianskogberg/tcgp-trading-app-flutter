class TradeMatch {
  final String cardId;
  final String userId;
  final String playerName;
  final String friendId;
  final String? icon;
  final DateTime? lastActiveAt;
  final String language;
  final bool hasMutualMatch;

  const TradeMatch({
    required this.cardId,
    required this.userId,
    required this.playerName,
    required this.friendId,
    this.icon,
    this.lastActiveAt,
    required this.language,
    this.hasMutualMatch = false,
  });

  factory TradeMatch.fromJson(Map<String, dynamic> json) => TradeMatch(
        cardId: json['card_id'] as String,
        userId: json['user_id'] as String,
        playerName: json['player_name'] as String? ?? 'Unknown',
        friendId: json['friend_id'] as String? ?? '',
        icon: json['icon'] as String?,
        lastActiveAt: json['last_active_at'] != null
            ? DateTime.parse(json['last_active_at'] as String)
            : null,
        language: json['language'] as String? ?? 'ANY',
        hasMutualMatch: json['has_mutual_match'] as bool? ?? false,
      );
}
