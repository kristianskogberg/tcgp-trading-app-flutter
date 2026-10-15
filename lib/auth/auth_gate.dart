import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tcgp_trading_app/screens/main_screen.dart';
import 'package:tcgp_trading_app/screens/onboarding_screen.dart';

/// The signed-in session after every auth event, with stream errors dropped.
///
/// gotrue reports failures such as a token refresh that couldn't reach the
/// network (common on a cold start) as *errors* on
/// [GoTrueClient.onAuthStateChange] while keeping the session, and retries
/// the refresh later. Only an event without a session (`signedOut`) means the
/// user is actually gone.
Stream<Session?> sessionChanges(GoTrueClient auth) => auth.onAuthStateChange
    .map((state) => state.session)
    .handleError((Object error, StackTrace stackTrace) {
      debugPrint('Auth stream error, keeping current session: $error');
    });

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _auth = Supabase.instance.client.auth;
  late final Stream<Session?> _sessions = sessionChanges(_auth);

  @override
  Widget build(BuildContext context) {
    // Supabase.initialize has already restored any persisted session, so
    // currentSession is accurate before the stream's first event.
    return StreamBuilder<Session?>(
        stream: _sessions,
        initialData: _auth.currentSession,
        builder: (context, snapshot) {
          final session = snapshot.data;
          if (session != null) {
            return MainScreen(key: ValueKey(session.user.id));
          } else {
            return const OnboardingScreen();
          }
        });
  }
}
