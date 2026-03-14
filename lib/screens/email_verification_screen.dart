import 'dart:async';

import 'package:cloudflare_turnstile/cloudflare_turnstile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tcgp_trading_app/auth/auth_service.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _authService = AuthService();
  final _turnstileController = TurnstileController();

  bool _checking = false;
  bool _resending = false;
  bool _showResend = false;
  String? _resendError;
  String? _captchaToken;

  int _resendCooldownSeconds = 0;
  Timer? _cooldownTimer;
  Timer? _showResendTimer;

  late final StreamSubscription<AuthState> _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.userUpdated &&
          _authService.isEmailVerified) {
        _onVerified();
      }
    });
    // Show resend option after 60 seconds
    _showResendTimer = Timer(const Duration(seconds: 60), () {
      if (mounted) setState(() => _showResend = true);
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    _cooldownTimer?.cancel();
    _showResendTimer?.cancel();
    _turnstileController.dispose();
    super.dispose();
  }

  Future<void> _onVerified() async {
    if (!mounted) return;
    await Supabase.instance.client.auth.refreshSession();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Email verified — account linked!')),
    );
    Navigator.pop(context);
  }

  Future<void> _checkManually() async {
    setState(() => _checking = true);
    try {
      await Supabase.instance.client.auth.refreshSession();
      if (_authService.isEmailVerified) {
        _onVerified();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Email not verified yet. Please check your inbox.')),
        );
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    if (_captchaToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete the CAPTCHA')),
      );
      return;
    }

    setState(() {
      _resending = true;
      _resendError = null;
    });
    try {
      await _authService.resendVerificationEmail(widget.email,
          captchaToken: _captchaToken);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email resent.')),
        );
        _startResendCooldown();
      }
    } catch (e) {
      if (mounted) setState(() => _resendError = 'Failed to resend: $e');
    } finally {
      if (mounted) {
        _turnstileController.refreshToken();
        setState(() {
          _resending = false;
          _captchaToken = null;
        });
      }
    }
  }

  void _startResendCooldown() {
    setState(() => _resendCooldownSeconds = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _resendCooldownSeconds--);
      if (_resendCooldownSeconds <= 0) t.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final siteKey = dotenv.env['TURNSTILE_SITE_KEY'] ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            const Icon(Icons.mark_email_unread_outlined,
                size: 64, color: Colors.white54),
            const SizedBox(height: 24),
            const Text(
              'Check your inbox',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'We sent a verification link to\n${widget.email}',
              style: const TextStyle(color: Colors.white70, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the link in the email, then come back here.',
              style: TextStyle(color: Colors.white38, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _checking ? null : _checkManually,
                child: _checking
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("I've verified my email"),
              ),
            ),
            if (_showResend) ...[
              const SizedBox(height: 24),
              const Text(
                "Didn't receive the email?",
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Center(
                child: SizedBox(
                  width: 300,
                  child: CloudFlareTurnstile(
                    siteKey: siteKey,
                    controller: _turnstileController,
                    options: TurnstileOptions(
                        theme: TurnstileTheme.dark,
                        mode: TurnstileMode.managed),
                    onTokenRecived: (token) {
                      setState(() => _captchaToken = token);
                    },
                    onTokenExpired: () {
                      setState(() => _captchaToken = null);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: (_resending ||
                          _resendCooldownSeconds > 0 ||
                          _captchaToken == null)
                      ? null
                      : _resend,
                  child: _resending
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _resendCooldownSeconds > 0
                              ? 'Resend email (${_resendCooldownSeconds}s)'
                              : 'Resend email',
                        ),
                ),
              ),
              if (_resendError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _resendError!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
