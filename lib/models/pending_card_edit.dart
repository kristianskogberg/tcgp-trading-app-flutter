class PendingCardEdit {
  final String cardId;
  final String type; // 'wishlist' or 'owned'
  final Set<String> languages;
  final Map<String, String> tradeConditions; // cardId -> language code (empty = open to all)
  PendingCardEdit({
    required this.cardId,
    required this.type,
    Set<String>? languages,
    Map<String, String>? tradeConditions,
  })  : languages = languages ?? {'ANY'},
        tradeConditions = tradeConditions ?? {};

  PendingCardEdit copyWith({
    Set<String>? languages,
    Map<String, String>? tradeConditions,
  }) =>
      PendingCardEdit(
        cardId: cardId,
        type: type,
        languages: languages ?? this.languages,
        tradeConditions: tradeConditions ?? this.tradeConditions,
      );
}
