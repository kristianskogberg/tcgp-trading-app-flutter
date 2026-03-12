import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/services/card_image_cache_manager.dart';

class OptimizedCardImage extends StatelessWidget {
  final String imageUrl;
  final bool isThumbnail;
  final double? height;
  final BoxFit fit;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, Object)? errorWidget;

  const OptimizedCardImage({
    super.key,
    required this.imageUrl,
    this.isThumbnail = true,
    this.height,
    this.fit = BoxFit.contain,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      cacheManager: CardImageCacheManager.instance,
      height: height,
      fit: fit,
      memCacheWidth: isThumbnail ? 200 : null,
      memCacheHeight: isThumbnail ? 300 : null,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: placeholder,
      errorWidget: errorWidget,
    );
  }
}
