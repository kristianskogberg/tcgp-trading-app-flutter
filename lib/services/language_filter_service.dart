import 'package:shared_preferences/shared_preferences.dart';
import 'package:tcgp_trading_app/utils/languages.dart';

class LanguageFilterService {
  static final LanguageFilterService _instance =
      LanguageFilterService._internal();
  factory LanguageFilterService() => _instance;
  LanguageFilterService._internal();

  static const _key = 'selected_languages_filter';
  Set<String>? _selected;

  Future<Set<String>> getSelectedLanguages() async {
    if (_selected != null) return _selected!;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_key);
    _selected = stored != null ? stored.toSet() : languages.keys.toSet();
    return _selected!;
  }

  Future<void> setSelectedLanguages(Set<String> selected) async {
    _selected = selected;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, selected.toList());
  }
}
