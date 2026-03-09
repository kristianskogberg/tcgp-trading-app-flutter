import 'package:flutter/material.dart';

Future<T?> showAppDialog<T>({
  required BuildContext context,
  String? title,
  required Widget content,
  String cancelText = 'Cancel',
  String primaryText = 'Save',
  T Function()? onPrimaryPressed,
  VoidCallback? onPrimaryAction,
  Color? primaryButtonColor,
  Color? primaryForegroundColor,
  bool centerContent = false,
}) {
  return showDialog<T>(
    context: context,
    builder: (context) => AppDialog<T>(
      title: title,
      content: content,
      cancelText: cancelText,
      primaryText: primaryText,
      onPrimaryPressed: onPrimaryPressed,
      onPrimaryAction: onPrimaryAction,
      primaryButtonColor: primaryButtonColor,
      primaryForegroundColor: primaryForegroundColor,
      centerContent: centerContent,
    ),
  );
}

class AppDialog<T> extends StatelessWidget {
  final String? title;
  final Widget content;
  final String cancelText;
  final String primaryText;
  final T Function()? onPrimaryPressed;
  final VoidCallback? onPrimaryAction;
  final Color? primaryButtonColor;
  final Color? primaryForegroundColor;
  final bool centerContent;

  const AppDialog({
    super.key,
    this.title,
    required this.content,
    this.cancelText = 'Cancel',
    this.primaryText = 'Save',
    this.onPrimaryPressed,
    this.onPrimaryAction,
    this.primaryButtonColor,
    this.primaryForegroundColor,
    this.centerContent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: centerContent
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
            ],
            DefaultTextStyle(
              style: const TextStyle(fontSize: 14, color: Colors.white70),
              child: content,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(cancelText),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      if (onPrimaryPressed != null) {
                        Navigator.pop(context, onPrimaryPressed!());
                      } else if (onPrimaryAction != null) {
                        Navigator.pop(context);
                        onPrimaryAction!();
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          primaryButtonColor ?? const Color(0xFF02F8AE),
                      foregroundColor:
                          primaryForegroundColor ?? Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(primaryText),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
