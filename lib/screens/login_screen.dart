import 'package:cloudflare_turnstile/cloudflare_turnstile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tcgp_trading_app/auth/auth_service.dart';
import 'package:tcgp_trading_app/utils/input_fields.dart';



class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final authService = AuthService();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _turnstileController = TurnstileController();

  String? _captchaToken;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _turnstileController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    try {
      await authService.signInWithGoogle();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted && !e.toString().contains('cancelled')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google sign-in failed')),
        );
      }
    }
  }

  Future<void> login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
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
      await authService.signInWithEmailPassword(email, password,
          captchaToken: _captchaToken);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid email or password')),
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
          title: const Text('Login'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            EmailField(controller: _emailController),
            const SizedBox(height: 20),
            PasswordField(controller: _passwordController),
            const SizedBox(height: 20),
            Center(
              child: SizedBox(
                width: 300,
                child: CloudFlareTurnstile(
                  siteKey: siteKey,
                  controller: _turnstileController,
                  options: TurnstileOptions(
                      theme: TurnstileTheme.dark, mode: TurnstileMode.managed),
                  onTokenRecived: (token) {
                    setState(() => _captchaToken = token);
                  },
                  onTokenExpired: () {
                    setState(() => _captchaToken = null);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: login,
              child: const Text('Login'),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(child: Divider(color: Colors.white24)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('or', style: TextStyle(color: Colors.white54)),
                ),
                const Expanded(child: Divider(color: Colors.white24)),
              ],
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _signInWithGoogle,
              icon: const Icon(Icons.g_mobiledata, size: 24),
              label: const Text('Sign in with Google'),
            ),
            const SizedBox(height: 20),
            GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Center(child: Text("New user? Get started")))
          ],
        ));
  }
}
