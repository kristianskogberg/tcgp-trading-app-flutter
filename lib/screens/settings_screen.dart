import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tcgp_trading_app/auth/auth_service.dart';
import 'package:tcgp_trading_app/auth/profile_service.dart';
import 'package:tcgp_trading_app/screens/feedback_screen.dart';
import 'package:tcgp_trading_app/screens/change_credentials_screen.dart';
import 'package:tcgp_trading_app/screens/optional_link_screen.dart';
import 'package:tcgp_trading_app/services/card_service.dart';
import 'package:tcgp_trading_app/services/notification_service.dart';
import 'package:tcgp_trading_app/services/user_card_service.dart';
import 'package:tcgp_trading_app/widgets/shared/app_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _openFeedback() async {
    final submitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const FeedbackScreen()),
    );
    if (submitted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feedback submitted — thank you!')),
      );
    }
  }

  Future<void> _deleteAccount() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _DeleteAccountDialog(),
    );
  }

  Future<void> _signOut() async {
    final isAnon = AuthService().isAnonymous;
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: 'Sign out',
      content: Text(
        isAnon
            ? 'Warning: Signing out will permanently delete your data unless you have linked an email. Continue?'
            : 'Are you sure you want to sign out?',
      ),
      primaryText: 'Sign out',
      onPrimaryPressed: () => true,
    );
    if (confirmed != true) return;
    try {
      if (isAnon) {
        await UserCardService().deleteAllUserCards();
        await ProfileService().deleteProfile();
      }
      await NotificationService().removeToken();
      await UserCardService().clearCache();
      await ProfileService().clearProfileCache();
      await CardService().clearCache();
      await AuthService().signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to sign out')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const _SectionHeader('Account'),
          if (AuthService().isAnonymous)
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Link Account'),
              subtitle: const Text('Save your data with email or Google'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OptionalLinkScreen()),
                );
                if (mounted) {
                  setState(() {});
                }
              },
            )
          else if (AuthService().isGoogleLinked)
            ListTile(
              leading: const Icon(Icons.g_mobiledata),
              title: const Text('Google Account'),
              subtitle: Text(AuthService().currentUser?.email ?? '—'),
            )
          else
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Email'),
              subtitle: Text(AuthService().currentUser?.email ?? '—'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ChangeCredentialsScreen()),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: _signOut,
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
            title: const Text('Delete Account',
                style: TextStyle(color: Colors.redAccent)),
            onTap: _deleteAccount,
          ),
          const _SectionHeader('Support'),
          ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: const Text('Feedback'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openFeedback,
          ),
          const _SectionHeader('About'),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final version = snapshot.hasData
                  ? 'v${snapshot.data!.version}+${snapshot.data!.buildNumber}'
                  : '—';
              return ListTile(
                title: Text('Version  $version'),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  int _secondsLeft = 5;
  bool _deleting = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
      }
      setState(() => _secondsLeft--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _performDelete() async {
    setState(() => _deleting = true);
    try {
      await AuthService().deleteAccount();
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete account: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _secondsLeft <= 0 && !_deleting;
    return PopScope(
      canPop: !_deleting,
      child: Dialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF141418),
                border: Border(bottom: BorderSide(color: Colors.white12)),
              ),
              child: const Text(
                'Delete Account',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _deleting
                        ? 'Deleting your account...'
                        : 'This will permanently delete your account and all your data, including your profile, wishlist, and listings. This cannot be undone.',
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  const SizedBox(height: 20),
                  if (_deleting)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white24),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: enabled ? _performDelete : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.black,
                              disabledBackgroundColor:
                                  Colors.redAccent.withOpacity(0.3),
                              disabledForegroundColor: Colors.black38,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                                enabled ? 'Delete' : 'Delete ($_secondsLeft)'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Colors.white12),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white38,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}
