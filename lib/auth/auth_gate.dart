import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tcgp_trading_app/screens/main_screen.dart';
import 'package:tcgp_trading_app/screens/onboarding_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final session = snapshot.hasData ? snapshot.data!.session : null;
          if (session != null) {
            return MainScreen(key: ValueKey(session.user.id));
          } else {
            return OnboardingScreen();
          }
        });
  }
}
