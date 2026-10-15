import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:tcgp_trading_app/collection/collection_draft.dart';
import 'package:tcgp_trading_app/utils/languages.dart';
import 'package:tcgp_trading_app/widgets/shared/language_picker_sheet.dart';

/// A settings row that shows the user's Preferred language and lets them
/// pick another specific language, which [save] stores.
class PreferredLanguageTile extends StatefulWidget {
  /// The saved preferred language, or null if unset.
  final String? preferredLanguage;

  /// Whether [preferredLanguage] is still loading; the row can't be changed
  /// until it's known.
  final bool loading;
  final Future<void> Function(String language) save;

  const PreferredLanguageTile({
    super.key,
    required this.preferredLanguage,
    this.loading = false,
    required this.save,
  });

  @override
  State<PreferredLanguageTile> createState() => _PreferredLanguageTileState();
}

class _PreferredLanguageTileState extends State<PreferredLanguageTile> {
  bool _saving = false;

  String? get _language => widget.preferredLanguage;

  String get _subtitle {
    if (widget.loading) return 'Loading…';
    final language = _language;
    return language == null
        ? '${languages[fallbackPreferredLanguage]} (default)'
        : languages[language]!;
  }

  Future<void> _pick() async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      backgroundColor: const Color(0xFF1E1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => LanguagePickerSheet(
        selected: {_language ?? fallbackPreferredLanguage},
        multiSelect: false,
      ),
    );
    final chosen = result?.singleOrNull;
    if (chosen == null || chosen == _language || !mounted) return;

    setState(() => _saving = true);
    try {
      await widget.save(chosen);
    } catch (e) {
      debugPrint('Failed to save preferred language: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Couldn't save your preferred language. Try again."),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: PhosphorIcon(PhosphorIcons.translate()),
      title: const Text('Preferred language'),
      subtitle: Text(_subtitle),
      trailing: _saving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : PhosphorIcon(PhosphorIcons.caretRight()),
      enabled: !widget.loading,
      onTap: _saving ? null : _pick,
    );
  }
}
