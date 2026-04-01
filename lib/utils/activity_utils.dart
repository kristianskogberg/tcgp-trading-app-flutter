import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/config/app_colors.dart';

Color activityColor(DateTime? lastActiveAt) {
  if (lastActiveAt == null) return Colors.white24;
  final diff = DateTime.now().toUtc().difference(lastActiveAt.toUtc());
  if (diff.inMinutes < 30) return AppColors.primary;
  if (diff.inHours < 6) return Colors.amber;
  return Colors.white24;
}

String activityLabel(DateTime? lastActiveAt) {
  if (lastActiveAt == null) return 'Offline';
  final diff = DateTime.now().toUtc().difference(lastActiveAt.toUtc());
  if (diff.inMinutes < 30) return 'Active now';
  if (diff.inHours < 6) return 'Active recently';
  return 'Offline';
}
