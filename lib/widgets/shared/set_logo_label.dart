import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/config/app_colors.dart';
import 'package:tcgp_trading_app/utils/set_image_url.dart';

class SetLogoLabel extends StatelessWidget {
  final String setId;
  final Color fallbackColor;
  final double width;
  final double height;

  const SetLogoLabel({
    super.key,
    required this.setId,
    this.fallbackColor = Colors.white70,
    this.width = 68,
    this.height = 22,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: CachedNetworkImage(
          imageUrl: setImageUrl(setId),
          width: width,
          height: height,
          memCacheWidth: (width * 3).round(),
          memCacheHeight: (height * 3).round(),
          fit: BoxFit.contain,
          placeholder: (context, url) => const _LogoPlaceholder(),
          errorWidget: (context, url, error) => FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              setId,
              maxLines: 1,
              style: TextStyle(
                color: fallbackColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoPlaceholder extends StatelessWidget {
  const _LogoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        width: 36,
        height: 8,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.18),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}
