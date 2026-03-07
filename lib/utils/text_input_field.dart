import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TextInputField extends StatefulWidget {
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
  final IconData? icon;
  final bool enabled;
  final String? infoText;

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
    this.icon,
    this.enabled = true,
    this.infoText,
  });

  @override
  State<TextInputField> createState() => _TextInputFieldState();
}

class _TextInputFieldState extends State<TextInputField> {
  late bool _obscured;
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
    _focusNode.addListener(() {
      setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    final colorScheme = Theme.of(context).colorScheme;

    final normalColor = colorScheme.outline;
    final focusColor = colorScheme.primary;
    final errorColor = colorScheme.error;

    OutlineInputBorder buildBorder(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(width: width, color: color),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.label,
              style: TextStyle(
                color: hasError ? errorColor : Colors.white70,
              ),
            ),
            if (widget.infoText != null) ...[
              const SizedBox(width: 4),
              Tooltip(
                message: widget.infoText!,
                preferBelow: false,
                triggerMode: TooltipTriggerMode.tap,
                showDuration: const Duration(seconds: 6),
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: hasError ? errorColor : Colors.white38,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          keyboardType: widget.keyboardType,
          inputFormatters: widget.inputFormatters,
          obscureText: _obscured,
          maxLength: widget.maxLength,
          onChanged: widget.onChanged,
          enabled: widget.enabled,
          textCapitalization: widget.textCapitalization,
          decoration: InputDecoration(
            hintText: widget.hint,
            errorText: widget.errorText,
            counterText: '',
            prefixIcon: widget.icon != null
                ? Icon(widget.icon,
                    size: 20,
                    color: hasError
                        ? errorColor
                        : _focused
                            ? focusColor
                            : null)
                : null,
            suffixIcon: widget.obscureText
                ? IconButton(
                    icon: Icon(
                      _obscured ? Icons.visibility_off : Icons.visibility,
                      size: 20,
                      color: hasError
                          ? errorColor
                          : _focused
                              ? focusColor
                              : null,
                    ),
                    onPressed: () => setState(() => _obscured = !_obscured),
                  )
                : null,
            filled: true,
            fillColor: colorScheme.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: buildBorder(hasError ? errorColor : normalColor),
            enabledBorder: buildBorder(hasError ? errorColor : normalColor),
            focusedBorder:
                buildBorder(hasError ? errorColor : focusColor, width: 2),
            errorBorder: buildBorder(errorColor),
            focusedErrorBorder: buildBorder(errorColor, width: 2),
          ),
        ),
      ],
    );
  }
}
