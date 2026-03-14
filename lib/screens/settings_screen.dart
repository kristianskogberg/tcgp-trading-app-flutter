import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tcgp_trading_app/auth/auth_service.dart';
import 'package:tcgp_trading_app/auth/profile_service.dart';
import 'package:tcgp_trading_app/screens/feedback_screen.dart';
import 'package:tcgp_trading_app/screens/change_credentials_screen.dart';
import 'package:tcgp_trading_app/screens/link_account_screen.dart';
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
      await UserCardService().clearCache();
      await ProfileService().clearProfileCache();
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
              subtitle: const Text('Save your data with an email address'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LinkAccountScreen()),
                );
                if (mounted) {
                  setState(() {});
                }
              },
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
