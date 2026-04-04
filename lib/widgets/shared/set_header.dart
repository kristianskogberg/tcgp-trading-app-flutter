import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/utils/constants.dart';
import 'package:tcgp_trading_app/utils/set_image_url.dart';

class SetHeader extends StatelessWidget {
  final String setId;
  final bool isFirst;

  const SetHeader({
    super.key,
    required this.setId,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: isFirst ? 6 : 16,
        bottom: 8,
        left: 6,
        right: 6,
      ),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: CachedNetworkImage(
              imageUrl: setImageUrl(setId),
              height: UIConstants.setImageHeight,
              fit: BoxFit.contain,
              errorWidget: (context, url, error) => Text(
                setId,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}
