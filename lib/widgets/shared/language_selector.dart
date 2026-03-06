import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/utils/languages.dart';

class LanguageSelector extends StatefulWidget {
  final String title;
  final Set<String> selectedLanguages;
  final Future<void> Function(String language, bool selected) onToggle;

  const LanguageSelector({
    super.key,
    required this.title,
    required this.selectedLanguages,
    required this.onToggle,
  });

  @override
  State<LanguageSelector> createState() => _LanguageSelectorState();
}

class _LanguageSelectorState extends State<LanguageSelector> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.selectedLanguages);
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
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: languages.entries.map((entry) {
              final isSelected = _selected.contains(entry.key);
              return FilterChip(
                label: Text(entry.value),
                selected: isSelected,
                onSelected: (selected) async {
                  setState(() {
                    if (selected) {
                      _selected.add(entry.key);
                    } else {
                      _selected.remove(entry.key);
                    }
                  });
                  await widget.onToggle(entry.key, selected);
                },
                selectedColor: const Color(0xFF02F8AE).withAlpha(51),
                checkmarkColor: const Color(0xFF02F8AE),
                labelStyle: TextStyle(
                  color: isSelected
                      ? const Color(0xFF02F8AE)
                      : Colors.white70,
                  fontSize: 13,
                ),
                backgroundColor: const Color(0xFF2A2A32),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFF02F8AE)
                      : Colors.white24,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
