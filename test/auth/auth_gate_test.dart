// notifyAllSubscribers / notifyException are how gotrue itself feeds
// onAuthStateChange, so the tests drive the real stream through them.
// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tcgp_trading_app/auth/auth_gate.dart';

Session _session(String userId) => Session(
      accessToken: 'access-token',
      tokenType: 'bearer',
      user: User(
        id: userId,
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00Z',
      ),
    );

void main() {
  late GoTrueClient auth;

  setUp(() {
    auth = GoTrueClient(url: 'http://localhost', autoRefreshToken: false);
  });

  tearDown(() => auth.dispose());

  test('a failed token refresh keeps the user signed in', () async {
    final sessions = <Session?>[];
    final sub = sessionChanges(auth).listen(sessions.add);

    auth.notifyAllSubscribers(AuthChangeEvent.initialSession,
        session: _session('anon-user'));
    auth.notifyException(AuthRetryableFetchException(message: 'offline'));
    await pumpEventQueue();

    expect(sessions.map((s) => s?.user.id), ['anon-user']);
    await sub.cancel();
  });

  test('a sign-out clears the session', () async {
    final sessions = <Session?>[];
    final sub = sessionChanges(auth).listen(sessions.add);

    auth.notifyAllSubscribers(AuthChangeEvent.initialSession,
        session: _session('anon-user'));
    auth.notifyAllSubscribers(AuthChangeEvent.signedOut);
    await pumpEventQueue();

    expect(sessions.map((s) => s?.user.id), ['anon-user', null]);
    await sub.cancel();
  });
}
