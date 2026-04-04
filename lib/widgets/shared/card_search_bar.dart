import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class CardSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const CardSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: TextInputType.text,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Search cards...',
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 15),
          prefixIcon: PhosphorIcon(PhosphorIcons.magnifyingGlass(),
              color: Colors.white38, size: 20),
          suffixIcon: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              if (controller.text.isEmpty) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: PhosphorIcon(PhosphorIcons.x(),
                    color: Colors.white54, size: 18),
                onPressed: onClear,
              );
            },
          ),
          filled: true,
          fillColor: const Color(0xFF1E1E24),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
