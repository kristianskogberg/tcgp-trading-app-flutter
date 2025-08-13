import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcgp_trading_app/auth/profile_service.dart';
import 'package:tcgp_trading_app/screens/home_screen.dart';
import 'package:tcgp_trading_app/screens/main_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _usernameController = TextEditingController();
  final _friendIdController = TextEditingController();
  final _profileService = ProfileService();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_clearErrorMessage);
    _friendIdController.addListener(_clearErrorMessage);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _friendIdController.dispose();
    super.dispose();
  }

  void _clearErrorMessage() {
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });
    }
  }

  void saveProfile() async {
    final username = _usernameController.text.trim();
    final friendId = _friendIdController.text.trim();

    if (username.isEmpty || friendId.isEmpty) {
      setState(() {
        _errorMessage = 'Username and Friend ID cannot be empty.';
      });
      return;
    }

    if (friendId.length != 12) {
      setState(() {
        _errorMessage = 'Friend ID must be 12 digits long.';
      });
      return;
    }

    try {
      await _profileService.saveProfile(username: username, friendId: friendId);
      setState(() {
        _errorMessage = null;
      });

      // navigate to home screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => MainScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
      ),
      body: Column(
        children: [
          Text('To get started, please complete your profile.'),
          if (_errorMessage != null) ...[
            SizedBox(height: 10),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red),
            ),
          ],
          SizedBox(height: 20),
          TextField(
            controller: _usernameController,
            decoration: InputDecoration(labelText: 'Username'),
          ),
          SizedBox(height: 20),
          TextField(
            controller: _friendIdController,
            decoration: InputDecoration(labelText: 'Friend ID'),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: saveProfile,
            child: Text('Complete Profile'),
          ),
        ],
      ),
    );
  }
}
