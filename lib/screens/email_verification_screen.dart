import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tcgp_trading_app/auth/auth_service.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final bool fromOnboarding;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    this.fromOnboarding = false,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _authService = AuthService();

  bool _checking = false;
  bool _resending = false;
  bool _showResend = false;
  String? _resendError;

  int _resendCooldownSeconds = 0;
  Timer? _cooldownTimer;
  Timer? _showResendTimer;

  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (!mounted) return;
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
    _authSub?.cancel();
    _cooldownTimer?.cancel();
    _showResendTimer?.cancel();
    super.dispose();
  }

  Future<void> _onVerified() async {
    if (!mounted) return;
    await Supabase.instance.client.auth.refreshSession();
    if (!mounted) return;
    if (!widget.fromOnboarding) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email verified — account linked!')),
      );
    }
    Navigator.pop(context, true);
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
    } catch (e) {
      debugPrint('Failed to refresh session: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not check verification status. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _resendError = null;
    });
    try {
      await _authService.resendVerificationEmail(widget.email);
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
        setState(() => _resending = false);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            PhosphorIcon(PhosphorIcons.envelopeOpen(),
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
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: (_resending || _resendCooldownSeconds > 0)
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
