class PocketCard {
  final String id;
  final String set;
  final int number;
  final String name;
  final String rarity;
  final String pack;
  final String imageUrl;
  final String type;
  final bool fullart;
  final bool ex;

  PocketCard({
    required this.id,
    required this.name,
    required this.rarity,
    required this.pack,
    required this.imageUrl,
    required this.type,
    this.fullart = false,
    this.ex = false,
  })  : set = _extractSet(id),
        number = _extractNumber(id);

  static String _extractSet(String id) {
    final dashIndex = id.lastIndexOf('-');
    return dashIndex >= 0 ? id.substring(0, dashIndex) : id;
  }

  static int _extractNumber(String id) {
    final dashIndex = id.lastIndexOf('-');
    if (dashIndex < 0) return 0;
    return int.tryParse(id.substring(dashIndex + 1)) ?? 0;
  }

  factory PocketCard.fromJson(Map<String, dynamic> json) {
    return PocketCard(
      id: json['id'] as String,
      name: json['name'] as String,
      rarity: json['rarity'] as String? ?? '',
      pack: json['pack'] as String? ?? '',
      imageUrl: json['image'] as String? ?? '',
      type: json['type'] as String? ?? '',
      fullart: json['fullart'] as bool? ?? false,
      ex: json['ex'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'rarity': rarity,
        'pack': pack,
        'image': imageUrl,
        'type': type,
        'fullart': fullart,
        'ex': ex,
      };
}
