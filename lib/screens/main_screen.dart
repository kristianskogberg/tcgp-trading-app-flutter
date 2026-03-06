import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/screens/home_screen.dart';
import 'package:tcgp_trading_app/screens/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentScreenIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _selectScreen(int index) {
    Navigator.pop(context); // close drawer
    setState(() {
      _currentScreenIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        backgroundColor: const Color(0xFF141418),
        child: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Pocket Trading',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              ListTile(
                leading: const Icon(Icons.home),
                title: const Text('Home'),
                selected: _currentScreenIndex == 0,
                selectedColor: const Color(0xFF02F8AE),
                iconColor: Colors.white54,
                textColor: Colors.white70,
                onTap: () => _selectScreen(0),
              ),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Profile'),
                selected: _currentScreenIndex == 1,
                selectedColor: const Color(0xFF02F8AE),
                iconColor: Colors.white54,
                textColor: Colors.white70,
                onTap: () => _selectScreen(1),
              ),
            ],
          ),
        ),
      ),
      body: _currentScreenIndex == 0
          ? HomeScreen(onMenuTap: _openDrawer)
          : ProfileScreen(onMenuTap: _openDrawer),
    );
  }
}
