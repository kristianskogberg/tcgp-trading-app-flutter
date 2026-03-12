import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CardImageCacheManager {
  static const _key = 'pokemonCardImages';

  static final instance = CacheManager(
    Config(
      _key,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 500,
    ),
  );
}
