import 'package:tcgp_trading_app/utils/languages.dart';

/// The user's Preferred language stored on their [profile] row, or null if
/// it's unset. Anything but a specific language counts as unset.
String? preferredLanguageOf(Map<String, dynamic>? profile) {
  final value = profile?['preferred_language'];
  return value is String && languages.containsKey(value) ? value : null;
}
