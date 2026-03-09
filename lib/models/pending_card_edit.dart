class PendingCardEdit {
  final String cardId;
  final String type; // 'wishlist' or 'owned'
  final Set<String> languages;
  PendingCardEdit({
    required this.cardId,
    required this.type,
    Set<String>? languages,
  }) : languages = languages ?? {'ANY'};

  PendingCardEdit copyWith({Set<String>? languages}) => PendingCardEdit(
        cardId: cardId,
        type: type,
        languages: languages ?? this.languages,
      );
}
