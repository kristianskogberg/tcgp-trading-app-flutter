import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/auth/auth_service.dart';
import 'package:tcgp_trading_app/auth/profile_service.dart';
import 'package:tcgp_trading_app/screens/link_account_screen.dart';

class OptionalLinkScreen extends StatefulWidget {
  /// When non-null, the screen is in onboarding mode (shows "Skip for now").
  /// When null, it's in settings mode (shows back button, pops on done).
  final VoidCallback? onContinue;

  const OptionalLinkScreen({super.key, this.onContinue});

  @override
  State<OptionalLinkScreen> createState() => _OptionalLinkScreenState();
}

class _OptionalLinkScreenState extends State<OptionalLinkScreen> {
  bool _linked = false;
  bool _loading = false;
  String? _linkedMethod; // 'email' or 'google'

  bool get _isFromOnboarding => widget.onContinue != null;

  Future<void> _linkWithEmail() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LinkAccountScreen(fromOnboarding: _isFromOnboarding),
      ),
    );
    if (result == true && mounted) {
      setState(() {
        _linked = true;
        _linkedMethod = 'email';
      });
    }
  }

  Future<void> _linkWithGoogle() async {
    setState(() => _loading = true);
    try {
      await AuthService().linkGoogleAccount();
      await ProfileService().clearProfileCache();
      if (mounted) {
        setState(() {
          _linked = true;
          _loading = false;
          _linkedMethod = 'google';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        final message =
            e.toString().contains('cancelled') ? null : 'Google sign-in failed';
        if (message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      }
    }
  }

  void _onDone() {
    if (_isFromOnboarding) {
      widget.onContinue!();
    } else {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Link Account'),
        automaticallyImplyLeading: !_isFromOnboarding,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            if (_linked) ...[
              const Icon(Icons.check_circle_outline,
                  size: 72, color: Colors.greenAccent),
              const SizedBox(height: 24),
              const Text(
                'Account linked successfully!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _linkedMethod == 'google'
                    ? 'Your Google account is connected.'
                    : 'You can log in with your email anytime.',
                style: const TextStyle(color: Colors.white70, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              const Icon(Icons.shield_outlined,
                  size: 72, color: Colors.white54),
              const SizedBox(height: 24),
              const Text(
                'Link your account',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Link an account to protect your data. This is optional — you can always do it later in Settings.',
                style: TextStyle(color: Colors.white70, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _BenefitRow(
                icon: Icons.cloud_done_outlined,
                text: 'Save your cards and trades',
              ),
              const SizedBox(height: 16),
              _BenefitRow(
                icon: Icons.login,
                text: 'Log in on any device',
              ),
              const SizedBox(height: 16),
              _BenefitRow(
                icon: Icons.restart_alt,
                text: 'Recover your account if you reinstall',
              ),
            ],
            const Spacer(),
            if (_linked)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _onDone,
                  child: Text(_isFromOnboarding ? 'Continue' : 'Done'),
                ),
              )
            else ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _linkWithGoogle,
                  icon: _loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.g_mobiledata, size: 24),
                  label: const Text('Continue with Google'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _linkWithEmail,
                  child: const Text('Link with Email'),
                ),
              ),
              if (_isFromOnboarding) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: widget.onContinue,
                    child: const Text('Skip for now'),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BenefitRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
        ),
      ],
    );
  }
}
