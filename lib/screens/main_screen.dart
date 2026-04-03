import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tcgp_trading_app/auth/profile_service.dart';
import 'package:tcgp_trading_app/screens/conversations_screen.dart';
import 'package:tcgp_trading_app/screens/home_screen.dart';
import 'package:tcgp_trading_app/screens/optional_link_screen.dart';
import 'package:tcgp_trading_app/screens/profile_screen.dart';
import 'package:tcgp_trading_app/screens/settings_screen.dart';
import 'package:tcgp_trading_app/services/chat_service.dart';
import 'package:tcgp_trading_app/config/app_colors.dart';
import 'package:tcgp_trading_app/services/notification_service.dart';

class MainScreen extends StatefulWidget {
  /// When true, shows the link-account prompt once after onboarding.
  static bool showLinkPrompt = false;

  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentScreenIndex = 0;
  final _conversationsRefresh = ValueNotifier<int>(0);
  final _chatService = ChatService();
  bool _hasUnread = false;
  RealtimeChannel? _conversationsChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ProfileService().updateLastActive();
    NotificationService().initialize();
    _checkUnread();
    _conversationsChannel = _chatService.subscribeToNewMessages(() {
      _checkUnread();
    });
    if (MainScreen.showLinkPrompt) {
      MainScreen.showLinkPrompt = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const OptionalLinkScreen(fromOnboarding: true),
            ),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    if (_conversationsChannel != null) {
      _chatService.unsubscribe(_conversationsChannel!);
    }
    _conversationsRefresh.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ProfileService().updateLastActive();
      _checkUnread();
    }
  }

  Future<void> _checkUnread() async {
    try {
      final count = await _chatService.getTotalUnreadCount();
      if (!mounted) return;
      setState(() => _hasUnread = count > 0);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentScreenIndex,
        children: [
          const HomeScreen(),
          ConversationsScreen(
            refreshNotifier: _conversationsRefresh,
            onUnreadChanged: _checkUnread,
          ),
          ProfileScreen(
            onProfileSaved: () => setState(() => _currentScreenIndex = 0),
          ),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 44,
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(),
        child: NavigationBar(
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          backgroundColor: const Color(0xFF141418),
          indicatorColor: Colors.transparent,
          selectedIndex: _currentScreenIndex,
          onDestinationSelected: (index) {
            if (index == 1) {
              _conversationsRefresh.value++;
            }
            setState(() => _currentScreenIndex = index);
            // Re-check badge when switching tabs (user may have read messages)
            _checkUnread();
          },
          destinations: [
            NavigationDestination(
              icon: PhosphorIcon(PhosphorIcons.house()),
              selectedIcon: PhosphorIcon(
                  PhosphorIcons.house(PhosphorIconsStyle.fill),
                  color: AppColors.primary),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: _hasUnread,
                smallSize: 10,
                backgroundColor: AppColors.primary,
                child: PhosphorIcon(PhosphorIcons.chats()),
              ),
              selectedIcon: Badge(
                isLabelVisible: _hasUnread,
                smallSize: 10,
                backgroundColor: AppColors.primary,
                child: PhosphorIcon(
                    PhosphorIcons.chats(PhosphorIconsStyle.fill),
                    color: AppColors.primary),
              ),
              label: 'Messages',
            ),
            NavigationDestination(
              icon: PhosphorIcon(PhosphorIcons.user()),
              selectedIcon: PhosphorIcon(
                  PhosphorIcons.user(PhosphorIconsStyle.fill),
                  color: AppColors.primary),
              label: 'Profile',
            ),
            NavigationDestination(
              icon: PhosphorIcon(PhosphorIcons.gear()),
              selectedIcon: PhosphorIcon(
                  PhosphorIcons.gear(PhosphorIconsStyle.fill),
                  color: AppColors.primary),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
