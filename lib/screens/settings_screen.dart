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

  Future<void> _clearAllCaches() async {
    await UserCardService().clearCache();
    await ProfileService().clearProfileCache();
    await CardService().clearCache();
  }

  Future<void> _deleteAccount() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DestructiveActionDialog(
        title: 'Delete Account',
        description:
            'This will permanently delete your account and all your data, including your profile, wishlist, and listings. This cannot be undone.',
        loadingText: 'Deleting your account...',
        confirmLabel: 'Delete',
        accentColor: Colors.redAccent,
        onConfirm: () async {
          await AuthService().deleteAccount();
          await _clearAllCaches();
        },
      ),
    );
  }

  Future<void> _signOut() async {
    final isAnon = AuthService().isAnonymous;
    if (isAnon) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _DestructiveActionDialog(
          title: 'Sign Out',
          description:
              'Signing out will permanently delete all your data, including your profile, wishlist, and listings. This cannot be undone.',
          loadingText: 'Signing out...',
          confirmLabel: 'Sign out',
          accentColor: Colors.redAccent,
          showWarningBadge: true,
          onConfirm: () async {
            await UserCardService().deleteAllUserCards();
            await ProfileService().deleteProfile();
            await NotificationService().removeToken();
            await _clearAllCaches();
            await AuthService().signOut();
          },
        ),
      );
      return;
    }
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: 'Sign out',
      content: const Text('Are you sure you want to sign out?'),
      primaryText: 'Sign out',
      onPrimaryPressed: () => true,
    );
    if (confirmed != true) return;
    try {
      await NotificationService().removeToken();
      await _clearAllCaches();
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

class _DestructiveActionDialog extends StatefulWidget {
  final String title;
  final String description;
  final String loadingText;
  final String confirmLabel;
  final Color accentColor;
  final bool showWarningBadge;
  final Future<void> Function() onConfirm;

  const _DestructiveActionDialog({
    required this.title,
    required this.description,
    required this.loadingText,
    required this.confirmLabel,
    required this.accentColor,
    this.showWarningBadge = false,
    required this.onConfirm,
  });

  @override
  State<_DestructiveActionDialog> createState() =>
      _DestructiveActionDialogState();
}

class _DestructiveActionDialogState extends State<_DestructiveActionDialog> {
  int _secondsLeft = 5;
  bool _running = false;
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

  Future<void> _perform() async {
    setState(() => _running = true);
    try {
      await widget.onConfirm();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _running = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.title} failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _secondsLeft <= 0 && !_running;
    return PopScope(
      canPop: !_running,
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
              child: Text(
                widget.title,
                style: const TextStyle(
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
                  if (!_running && widget.showWarningBadge) ...[
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 16, color: Colors.amber),
                        SizedBox(width: 8),
                        Text(
                          'You have not linked an account yet',
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.amber,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    _running ? widget.loadingText : widget.description,
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  const SizedBox(height: 20),
                  if (_running)
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
                            onPressed: enabled ? _perform : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: widget.accentColor,
                              foregroundColor: Colors.black,
                              disabledBackgroundColor:
                                  widget.accentColor.withOpacity(0.3),
                              disabledForegroundColor: Colors.black38,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(enabled
                                ? widget.confirmLabel
                                : '${widget.confirmLabel} ($_secondsLeft)'),
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
