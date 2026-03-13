import 'package:cloudflare_turnstile/cloudflare_turnstile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tcgp_trading_app/auth/auth_service.dart';
import 'package:tcgp_trading_app/auth/profile_service.dart';
import 'package:tcgp_trading_app/utils/input_fields.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _authService = AuthService();
  final _profileService = ProfileService();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _playerNameController = TextEditingController();
  final _friendIdController = TextEditingController();
  final _turnstileController = TurnstileController();

  String? _captchaToken;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _playerNameController.dispose();
    _friendIdController.dispose();
    _turnstileController.dispose();
    super.dispose();
  }

  Future<void> signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final playerName = _playerNameController.text.trim();
    final friendId = _friendIdController.text.trim();

    if (email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty ||
        playerName.isEmpty ||
        friendId.isEmpty) {
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

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    if (playerName.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Player Name must be at least 2 characters')),
      );
      return;
    }

    if (friendId.length != 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend ID must be 12 digits')),
      );
      return;
    }

    if (_captchaToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete the CAPTCHA')),
      );
      return;
    }

    try {
      await _authService.signUpWithEmailPassword(email, password,
          captchaToken: _captchaToken);
      try {
        await _profileService.saveProfile(
          playerName: playerName,
          friendId: friendId,
        );
      } catch (_) {
        // Profile save failed — the ProfileGate will catch this
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign up failed. Please try again.')),
        );
        _turnstileController.refreshToken();
        setState(() => _captchaToken = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final siteKey = dotenv.env['TURNSTILE_SITE_KEY'] ?? '';

    return Scaffold(
        appBar: AppBar(
          title: const Text('Register'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            EmailField(controller: _emailController),
            const SizedBox(height: 10),
            PasswordField(controller: _passwordController),
            const SizedBox(height: 10),
            PasswordField(
              controller: _confirmPasswordController,
              label: 'Confirm Password',
            ),
            const SizedBox(height: 20),
            PlayerNameField(controller: _playerNameController),
            const SizedBox(height: 10),
            FriendIdField(controller: _friendIdController),
            const SizedBox(height: 20),
            Center(
              child: SizedBox(
                width: 300,
                child: CloudFlareTurnstile(
                  siteKey: siteKey,
                  controller: _turnstileController,
                  onTokenRecived: (token) {
                    setState(() => _captchaToken = token);
                  },
                  onTokenExpired: () {
                    setState(() => _captchaToken = null);
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: signUp,
              child: const Text('Sign Up'),
            ),
            const SizedBox(height: 20),
          ],
        ));
  }
}
