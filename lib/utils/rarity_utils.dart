/// Maps rarity symbols from the card data to local asset paths.
const rarityAssets = <String, String>{
  '◊': 'images/rarities/1-diamond.png',
  '◊◊': 'images/rarities/2-diamond.png',
  '◊◊◊': 'images/rarities/3-diamond.png',
  '◊◊◊◊': 'images/rarities/4-diamond.png',
  '☆': 'images/rarities/1-star.png',
  '☆☆': 'images/rarities/2-star.png',
  '☆☆☆': 'images/rarities/3-star.png',
  '♕': 'images/rarities/crown.png',
};

/// Returns the local asset path for a rarity symbol, or null if not mapped.
String? getRarityAsset(String rarity) => rarityAssets[rarity];

// trade cost in shinedust (null means not tradeable)
const tradeCosts = <String, String>{
  '◊': '0',
  '◊◊': '0',
  '◊◊◊': '1200',
  '◊◊◊◊': '5000',
  '☆': '10,000',
  '☆☆': '25,000',
};

/// Returns the trade cost for a rarity, or null if not tradeable/mapped.
/// Cards from promo packs are also not tradeable.
String? getTradeCost(String rarity, {String pack = ''}) {
  if (pack.toLowerCase().contains('promo')) return null;
  return tradeCosts[rarity];
}

/// Whether a card is untradable based on rarity and pack.
bool isCardUntradable(String rarity, String pack) {
  const untradableRarities = {'☆☆☆', '♕', 'Promo'};
  return untradableRarities.contains(rarity) ||
      pack.toLowerCase().contains('promo');
}
