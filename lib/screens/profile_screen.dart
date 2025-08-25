import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcgp_trading_app/auth/profile_service.dart';
import 'package:tcgp_trading_app/screens/main_screen.dart';
import 'package:tcgp_trading_app/utils/text_input_field.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _usernameController = TextEditingController();
  final _friendIdController = TextEditingController();
  final _profileService = ProfileService();

  String? _usernameErrorMessage;
  String? _friendIdErrorMessage;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_clearErrorMessage);
    _friendIdController.addListener(_clearErrorMessage);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _profileService.getProfile();
      if (profile != null && mounted) {
        if (_usernameController.text.isEmpty) {
          _usernameController.text = profile['username'] ?? '';
        }
        if (_friendIdController.text.isEmpty) {
          _friendIdController.text = profile['friend_id'] ?? '';
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Load failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _friendIdController.dispose();
    super.dispose();
  }

  void _clearErrorMessage() {
    if (_usernameErrorMessage != null || _friendIdErrorMessage != null) {
      setState(() {
        _usernameErrorMessage = null;
        _friendIdErrorMessage = null;
      });
    }
  }

  bool _validateInputs() {
    final username = _usernameController.text.trim();
    final friendId = _friendIdController.text.trim();

    String? usernameErr;
    String? friendIdErr;

    if (username.isEmpty) {
      usernameErr = "Player Name cannot be empty.";
    } else if (username.length < 2) {
      usernameErr = "Min 2 characters.";
    }

    if (friendId.isEmpty) {
      friendIdErr = "Friend ID cannot be empty.";
    } else if (friendId.length != 12) {
      friendIdErr = "Friend ID must be 12 digits.";
    }

    setState(() {
      _usernameErrorMessage = usernameErr;
      _friendIdErrorMessage = friendIdErr;
    });

    return usernameErr == null && friendIdErr == null;
  }

  Future<void> saveProfile() async {
    if (!_validateInputs()) return;
    setState(() => _saving = true);
    try {
      await _profileService.saveProfile(
        username: _usernameController.text.trim(),
        friendId: _friendIdController.text.trim(),
      );
      // Cache already updated in service.
      _clearErrorMessage();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Profile update failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formValid = _usernameErrorMessage == null &&
        _friendIdErrorMessage == null &&
        _usernameController.text.trim().isNotEmpty &&
        _friendIdController.text.trim().length == 12;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  TextInputField(
                    controller: _usernameController,
                    errorText: _usernameErrorMessage,
                    label: "Player Name",
                    onChanged: (_) => _validateInputs(),
                  ),
                  const SizedBox(height: 20),
                  TextInputField(
                    controller: _friendIdController,
                    errorText: _friendIdErrorMessage,
                    label: 'Friend ID',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 12,
                    onChanged: (_) => _validateInputs(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          _saving ? null : (formValid ? saveProfile : null),
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
