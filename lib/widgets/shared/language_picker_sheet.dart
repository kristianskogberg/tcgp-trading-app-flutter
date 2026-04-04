import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/config/app_colors.dart';
import 'package:tcgp_trading_app/utils/languages.dart';

class LanguagePickerSheet extends StatefulWidget {
  final Set<String> selected;
  final bool showAny;
  final bool multiSelect;

  const LanguagePickerSheet({
    super.key,
    required this.selected,
    this.showAny = false,
    this.multiSelect = true,
  });

  @override
  State<LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<LanguagePickerSheet> {
  late Set<String> _selected;

  bool get _isAnySelected => _selected.contains('ANY');

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.selected);
  }

  void _selectAny() {
    setState(() => _selected = {'ANY'});
  }

  void _toggleLanguage(String key) {
    setState(() {
      if (widget.multiSelect) {
        _selected.remove('ANY');
        if (_selected.contains(key)) {
          _selected.remove(key);
        } else {
          _selected.add(key);
        }
      } else {
        _selected = {key};
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Select language',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (widget.showAny)
                FilterChip(
                  label: const Text('Any'),
                  selected: _isAnySelected,
                  onSelected: (_) => _selectAny(),
                  selectedColor: AppColors.primary.withOpacity(0.2),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: _isAnySelected ? AppColors.primary : Colors.white70,
                    fontSize: 13,
                  ),
                  backgroundColor: const Color(0xFF2A2A32),
                  side: BorderSide(
                    color: _isAnySelected ? AppColors.primary : Colors.white24,
                  ),
                ),
              ...languages.entries.map((entry) {
                final isSelected =
                    _isAnySelected || _selected.contains(entry.key);
                return FilterChip(
                  label: Text(entry.value),
                  selected: isSelected,
                  onSelected: (_) => _toggleLanguage(entry.key),
                  selectedColor: AppColors.primary.withOpacity(0.2),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.primary : Colors.white70,
                    fontSize: 13,
                  ),
                  backgroundColor: const Color(0xFF2A2A32),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : Colors.white24,
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selected.isNotEmpty
                  ? () => Navigator.pop(context, _selected)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.white12,
                disabledForegroundColor: Colors.white38,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
