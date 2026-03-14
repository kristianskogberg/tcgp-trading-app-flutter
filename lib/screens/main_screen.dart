import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tcgp_trading_app/auth/profile_service.dart';
import 'package:tcgp_trading_app/screens/conversations_screen.dart';
import 'package:tcgp_trading_app/screens/home_screen.dart';
import 'package:tcgp_trading_app/screens/profile_screen.dart';
import 'package:tcgp_trading_app/screens/settings_screen.dart';
import 'package:tcgp_trading_app/services/chat_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentScreenIndex = 0;
  bool _isBottomBarVisible = true;
  final _conversationsRefresh = ValueNotifier<int>(0);
  final _chatService = ChatService();
  bool _hasUnread = false;
  RealtimeChannel? _conversationsChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ProfileService().updateLastActive();
    _checkUnread();
    _conversationsChannel = _chatService.subscribeToNewMessages(() {
      _checkUnread();
    });
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
      body: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (notification.direction == ScrollDirection.forward) {
            if (!_isBottomBarVisible) {
              setState(() => _isBottomBarVisible = true);
            }
          } else if (notification.direction == ScrollDirection.reverse) {
            if (_isBottomBarVisible) {
              setState(() => _isBottomBarVisible = false);
            }
          }
          return false;
        },
        child: IndexedStack(
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
      ),
      bottomNavigationBar: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: _isBottomBarVisible ? 44 : 0,
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
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home, color: Color(0xFF02F8AE)),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: _hasUnread,
                smallSize: 10,
                backgroundColor: const Color(0xFF02F8AE),
                child: const Icon(Icons.chat_bubble_outline),
              ),
              selectedIcon: Badge(
                isLabelVisible: _hasUnread,
                smallSize: 10,
                backgroundColor: const Color(0xFF02F8AE),
                child:
                    const Icon(Icons.chat_bubble, color: Color(0xFF02F8AE)),
              ),
              label: 'Messages',
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person, color: Color(0xFF02F8AE)),
              label: 'Profile',
            ),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon:
                  const Icon(Icons.settings, color: Color(0xFF02F8AE)),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
