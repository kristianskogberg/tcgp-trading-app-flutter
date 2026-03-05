class PocketCard {
  final String set;
  final int number;
  final String rarity;
  final String name;
  final String imageUrl;
  final List<String> packs;

  PocketCard({
    required this.set,
    required this.number,
    required this.rarity,
    required this.name,
    required this.packs,
  }) : imageUrl = _buildImageUrl(set, number);

  static String _buildImageUrl(String set, int number) {
    final paddedNumber = number.toString().padLeft(3, '0');
    return 'https://assets.tcgdex.net/en/tcgp/$set/$paddedNumber/high.webp';
  }

  factory PocketCard.fromJson(Map<String, dynamic> json) {
    return PocketCard(
      set: json['set'] as String,
      number: json['number'] as int,
      rarity: json['rarity'] as String? ?? 'C',
      name: json['name'] as String,
      packs: (json['packs'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'set': set,
        'number': number,
        'rarity': rarity,
        'name': name,
        'packs': packs,
      };

  /// Unique identifier for this card
  String get id => '$set-$number';
}
