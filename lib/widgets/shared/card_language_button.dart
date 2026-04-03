import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class CardLanguageButton extends StatelessWidget {
  final Set<String> languages;
  final Color color;
  final VoidCallback? onTap;
  final bool rounded;

  const CardLanguageButton({
    super.key,
    required this.languages,
    required this.color,
    this.onTap,
    this.rounded = true,
  });

  String get _label {
    if (languages.contains('ANY')) return 'Any';
    if (languages.length == 1) return languages.first;
    final list = languages.toList();
    if (list.length == 2) return '${list[0]}, ${list[1]}';
    return '${list[0]}, +${list.length - 1}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A30).withAlpha(230),
          borderRadius: rounded ? BorderRadius.circular(8) : BorderRadius.zero,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(PhosphorIcons.globeSimple(), size: 18, color: color),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                _label,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
