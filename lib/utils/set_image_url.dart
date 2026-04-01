const _overrides = <String, String>{
  'P-A': 'https://www.serebii.net/tcgpocket/logo/promo-a.png',
  'P-B': 'https://www.serebii.net/tcgpocket/logo/promo-b.png',
  'P-C': 'https://www.serebii.net/tcgpocket/logo/promo-c.png',
  'P-D': 'https://www.serebii.net/tcgpocket/logo/promo-d.png',
};

String setImageUrl(String setId) =>
    _overrides[setId] ?? 'https://s3.limitlesstcg.com/pocket/sets/$setId.webp';
