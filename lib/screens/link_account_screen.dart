import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/auth/auth_service.dart';
import 'package:tcgp_trading_app/screens/email_verification_screen.dart';
import 'package:tcgp_trading_app/utils/input_fields.dart';

class LinkAccountScreen extends StatefulWidget {
  final bool fromOnboarding;

  const LinkAccountScreen({super.key, this.fromOnboarding = false});

  @override
  State<LinkAccountScreen> createState() => _LinkAccountScreenState();
}

class _LinkAccountScreenState extends State<LinkAccountScreen> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _linkEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    if (password != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _authService.linkEmail(email, password);
      if (mounted) {
        final verified = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => EmailVerificationScreen(
              email: email,
              fromOnboarding: widget.fromOnboarding,
            ),
          ),
        );
        if (mounted) Navigator.pop(context, verified ?? false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to link email: $e')),
        );
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Link Account')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          const Text(
            'Link an email address to keep your data if you reinstall the app.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          EmailField(controller: _emailController),
          const SizedBox(height: 16),
          PasswordField(controller: _passwordController),
          const SizedBox(height: 16),
          PasswordField(
              controller: _confirmPasswordController,
              label: 'Confirm Password'),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loading ? null : _linkEmail,
            child: _loading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Link Email'),
          ),
        ],
      ),
    );
  }
}
