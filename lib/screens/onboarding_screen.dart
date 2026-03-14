import 'package:cloudflare_turnstile/cloudflare_turnstile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tcgp_trading_app/auth/auth_service.dart';
import 'package:tcgp_trading_app/auth/profile_service.dart';
import 'package:tcgp_trading_app/screens/login_screen.dart';
import 'package:tcgp_trading_app/utils/input_fields.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _authService = AuthService();
  final _profileService = ProfileService();

  final _playerNameController = TextEditingController();
  final _friendIdController = TextEditingController();
  final _turnstileController = TurnstileController();

  String? _playerNameError;
  String? _friendIdError;
  String? _captchaToken;
  bool _loading = false;
  bool _captchaError = false;

  @override
  void initState() {
    super.initState();
    _playerNameController.addListener(() => setState(() {}));
    _friendIdController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _playerNameController.dispose();
    _friendIdController.dispose();
    _turnstileController.dispose();
    super.dispose();
  }

  void _retryCaptcha() {
    setState(() => _captchaError = false);
    _turnstileController.refreshToken();
  }

  bool _validate() {
    final name = _playerNameController.text.trim();
    final friendId = _friendIdController.text.trim();

    String? nameErr;
    String? friendIdErr;

    if (name.isEmpty) {
      nameErr = 'Player Name cannot be empty.';
    } else if (name.length < 2) {
      nameErr = 'Min 2 characters.';
    } else if (name.length > 14) {
      nameErr = 'Max 14 characters.';
    }

    if (friendId.isEmpty) {
      friendIdErr = 'Friend ID cannot be empty.';
    } else if (friendId.length != 12) {
      friendIdErr = 'Friend ID must be 12 digits.';
    }

    setState(() {
      _playerNameError = nameErr;
      _friendIdError = friendIdErr;
    });

    return nameErr == null && friendIdErr == null;
  }

  Future<void> _getStarted() async {
    if (!_validate()) return;
    setState(() => _loading = true);
    try {
      await _authService
          .signInAnonymously(captchaToken: _captchaToken)
          .timeout(const Duration(seconds: 15));
      await _profileService
          .saveProfile(
            playerName: _playerNameController.text.trim(),
            friendId: _friendIdController.text.trim(),
          )
          .timeout(const Duration(seconds: 15));
      // AuthGate stream fires automatically — no Navigator.push needed
    } catch (e) {
      debugPrint('OnboardingScreen error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        _turnstileController.refreshToken();
        setState(() {
          _loading = false;
          _captchaToken = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final siteKey = dotenv.env['TURNSTILE_SITE_KEY'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Get Started'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 16),
          const Text(
            'Enter your Pokémon TCG Pocket info to start trading.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          PlayerNameField(
            controller: _playerNameController,
            errorText: _playerNameError,
          ),
          const SizedBox(height: 16),
          FriendIdField(
            controller: _friendIdController,
            errorText: _friendIdError,
          ),
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              child: CloudFlareTurnstile(
                siteKey: siteKey,
                controller: _turnstileController,
                options: TurnstileOptions(
                    theme: TurnstileTheme.dark, mode: TurnstileMode.managed),
                onTokenRecived: (token) => setState(() {
                  _captchaToken = token;
                  _captchaError = false;
                }),
                onTokenExpired: () => setState(() => _captchaToken = null),
                onError: (_) => setState(() => _captchaError = true),
              ),
            ),
          ),
          if (_captchaError)
            Center(
              child: TextButton.icon(
                onPressed: _retryCaptcha,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry security check'),
              ),
            ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: (_loading || _captchaToken == null) ? null : _getStarted,
            child: _loading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Get Started'),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
            child: const Center(
              child: Text('Already have an account? Login here'),
            ),
          ),
        ],
      ),
    );
  }
}
