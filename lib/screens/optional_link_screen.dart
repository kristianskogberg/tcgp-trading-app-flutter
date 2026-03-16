import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/screens/link_account_screen.dart';

class OptionalLinkScreen extends StatefulWidget {
  final VoidCallback onContinue;

  const OptionalLinkScreen({super.key, required this.onContinue});

  @override
  State<OptionalLinkScreen> createState() => _OptionalLinkScreenState();
}

class _OptionalLinkScreenState extends State<OptionalLinkScreen> {
  bool _linked = false;

  Future<void> _linkAccount() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const LinkAccountScreen(fromOnboarding: true),
      ),
    );
    if (result == true && mounted) {
      setState(() => _linked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Link Account'),
        automaticallyImplyLeading: false,
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
              const Text(
                'You can log in with your email anytime.',
                style: TextStyle(color: Colors.white70, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              const Icon(Icons.shield_outlined,
                  size: 72, color: Colors.white54),
              const SizedBox(height: 24),
              const Text(
                'Secure your account',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Link an email to protect your data. This is optional — you can always do it later in Settings.',
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
                  onPressed: widget.onContinue,
                  child: const Text('Continue'),
                ),
              )
            else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _linkAccount,
                  child: const Text('Link Email'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: widget.onContinue,
                  child: const Text('Skip for now'),
                ),
              ),
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
