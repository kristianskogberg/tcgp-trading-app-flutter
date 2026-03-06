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
