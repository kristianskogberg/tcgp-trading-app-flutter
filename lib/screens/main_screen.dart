import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/screens/home_screen.dart';
import 'package:tcgp_trading_app/screens/profile_screen.dart';
import 'package:tcgp_trading_app/screens/settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentScreenIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentScreenIndex,
        children: [
          const HomeScreen(),
          ProfileScreen(
            onProfileSaved: () => setState(() => _currentScreenIndex = 0),
          ),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF141418),
        indicatorColor: Colors.transparent,
        selectedIndex: _currentScreenIndex,
        onDestinationSelected: (index) {
          setState(() => _currentScreenIndex = index);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home, color: Color(0xFF02F8AE)),
            label: 'Home',
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person, color: Color(0xFF02F8AE)),
            label: 'Profile',
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings, color: Color(0xFF02F8AE)),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
