import 'package:tcgp_trading_app/collection/collection.dart';

class PendingCardEdit {
  final String cardId;
  final CollectionItemKind kind;
  final Set<String> languages;

  PendingCardEdit({
    required this.cardId,
    required this.kind,
    Set<String>? languages,
  }) : languages = languages ?? {anyLanguage};

  PendingCardEdit copyWith({Set<String>? languages}) => PendingCardEdit(
        cardId: cardId,
        kind: kind,
        languages: languages ?? this.languages,
      );
}
