import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/auth/auth_service.dart';
import 'package:tcgp_trading_app/screens/email_verification_screen.dart';
import 'package:tcgp_trading_app/utils/input_fields.dart';
import 'package:tcgp_trading_app/widgets/shared/app_dialog.dart';

class ChangeCredentialsScreen extends StatefulWidget {
  const ChangeCredentialsScreen({super.key});

  @override
  State<ChangeCredentialsScreen> createState() =>
      _ChangeCredentialsScreenState();
}

class _ChangeCredentialsScreenState extends State<ChangeCredentialsScreen> {
  final _authService = AuthService();

  final _emailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _savingEmail = false;
  bool _savingPassword = false;
  bool _deletingAccount = false;

  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  @override
  void dispose() {
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changeEmail() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() => _emailError = 'Please enter a new email address.');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _emailError = 'Please enter a valid email address.');
      return;
    }
    setState(() {
      _emailError = null;
      _savingEmail = true;
    });

    try {
      await _authService.updateEmail(email);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => EmailVerificationScreen(email: email),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _emailError = 'Failed to update email: $e');
      }
    } finally {
      if (mounted) setState(() => _savingEmail = false);
    }
  }

  Future<void> _changePassword() async {
    final password = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    String? passwordErr;
    String? confirmErr;

    if (password.isEmpty) {
      passwordErr = 'Please enter a new password.';
    } else if (password.length < 6) {
      passwordErr = 'Password must be at least 6 characters.';
    }
    if (confirm.isEmpty) {
      confirmErr = 'Please confirm your new password.';
    } else if (password != confirm) {
      confirmErr = 'Passwords do not match.';
    }

    setState(() {
      _passwordError = passwordErr;
      _confirmPasswordError = confirmErr;
    });
    if (passwordErr != null || confirmErr != null) return;

    setState(() => _savingPassword = true);
    try {
      await _authService.updatePassword(password);
      if (mounted) {
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _passwordError = 'Failed to update password: $e');
      }
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: 'Delete Account',
      content: const Text(
        'This will permanently delete your account and all your data, including your profile, wishlist, and listings. This cannot be undone.',
      ),
      primaryText: 'Delete',
      primaryButtonColor: Colors.red,
      primaryForegroundColor: Colors.white,
      onPrimaryPressed: () => true,
    );
    if (confirmed != true) return;

    setState(() => _deletingAccount = true);
    try {
      await _authService.deleteAccount();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete account: $e')),
        );
        setState(() => _deletingAccount = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentEmail = _authService.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Email ──────────────────────────────────────────
          const _SectionLabel('Change Email'),
          Text(
            'Current: $currentEmail',
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 12),
          EmailField(controller: _emailController, errorText: _emailError),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _savingEmail ? null : _changeEmail,
              child: _savingEmail
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Update Email'),
            ),
          ),
          const SizedBox(height: 32),

          // ── Password ───────────────────────────────────────
          const _SectionLabel('Change Password'),
          PasswordField(
            controller: _newPasswordController,
            label: 'New Password',
            errorText: _passwordError,
          ),
          const SizedBox(height: 12),
          PasswordField(
            controller: _confirmPasswordController,
            label: 'Confirm New Password',
            errorText: _confirmPasswordError,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _savingPassword ? null : _changePassword,
              child: _savingPassword
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Update Password'),
            ),
          ),
          const SizedBox(height: 48),

          // ── Danger zone ────────────────────────────────────
          const Divider(color: Colors.white12),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _deletingAccount ? null : _deleteAccount,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
              ),
              child: _deletingAccount
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.redAccent),
                    )
                  : const Text('Delete Account'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
