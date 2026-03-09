import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcgp_trading_app/utils/text_input_field.dart';

class EmailField extends StatelessWidget {
  final TextEditingController controller;
  final String? errorText;

  const EmailField({super.key, required this.controller, this.errorText});

  @override
  Widget build(BuildContext context) {
    return TextInputField(
      controller: controller,
      label: 'Email',
      icon: Icons.email,
      keyboardType: TextInputType.emailAddress,
      errorText: errorText,
    );
  }
}

class PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? errorText;

  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return TextInputField(
      controller: controller,
      label: label,
      icon: Icons.lock,
      obscureText: true,
      errorText: errorText,
    );
  }
}

class PlayerNameField extends StatelessWidget {
  final TextEditingController controller;
  final String? errorText;

  const PlayerNameField({super.key, required this.controller, this.errorText});

  @override
  Widget build(BuildContext context) {
    return TextInputField(
      controller: controller,
      label: 'Player Name',
      icon: Icons.person,
      maxLength: 14,
      errorText: errorText,
    );
  }
}

class FriendIdField extends StatelessWidget {
  final TextEditingController controller;
  final String? errorText;

  const FriendIdField({super.key, required this.controller, this.errorText});

  @override
  Widget build(BuildContext context) {
    return TextInputField(
      controller: controller,
      label: 'Friend ID',
      icon: Icons.tag,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      maxLength: 12,
      errorText: errorText,
      infoText:
          'You can find your Friend ID in Pokémon TCGP by tapping the profile icon at the top of the home screen.',
    );
  }
}
