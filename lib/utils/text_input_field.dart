import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TextInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final int? maxLength;
  final String? errorText;
  final void Function(String)? onChanged;
  final TextCapitalization textCapitalization;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;

  const TextInputField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.obscureText = false,
    this.maxLength,
    this.errorText,
    this.onChanged,
    this.textCapitalization = TextCapitalization.none,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    const borderRadiusValue = 32.0;
    final hasError = (errorText != null && errorText!.isNotEmpty);
    final colorScheme = Theme.of(context).colorScheme;

    OutlineInputBorder buildBorder(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusValue),
          borderSide: BorderSide(width: width, color: color),
        );

    final normalColor = colorScheme.outline;
    final focusColor = colorScheme.primary;
    final errorColor = colorScheme.error;

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      obscureText: obscureText,
      maxLength: maxLength,
      onChanged: onChanged,
      enabled: enabled,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        counterText: '',
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: colorScheme.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        // Base borders (these will be swapped automatically, but we force red when error)
        border: buildBorder(hasError ? errorColor : normalColor),
        enabledBorder: buildBorder(hasError ? errorColor : normalColor),
        focusedBorder:
            buildBorder(hasError ? errorColor : focusColor, width: 2),
        errorBorder: buildBorder(errorColor),
        focusedErrorBorder: buildBorder(errorColor, width: 2),
      ),
    );
  }
}
