import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tcgp_trading_app/services/notification_service.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<AuthResponse> signInWithEmailPassword(String email, String password,
      {String? captchaToken}) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
      captchaToken: captchaToken,
    );
  }

  Future<AuthResponse> signUpWithEmailPassword(String email, String password,
      {String? captchaToken}) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      captchaToken: captchaToken,
    );
  }

  Future<AuthResponse> signInAnonymously({String? captchaToken}) async {
    return await _client.auth.signInAnonymously(captchaToken: captchaToken);
  }

  Future<UserResponse> linkEmail(String email, String password) async {
    return await _client.auth.updateUser(
      UserAttributes(email: email, password: password),
    );
  }

  Future<UserResponse> updateEmail(String newEmail) async {
    return await _client.auth.updateUser(
      UserAttributes(email: newEmail),
    );
  }

  Future<UserResponse> updatePassword(String newPassword) async {
    return await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  Future<void> deleteAccount() async {
    // Deletes app data first (while still authenticated so RLS permits it),
    // then removes the auth user via a SECURITY DEFINER RPC, then signs out.
    final userId = _client.auth.currentUser!.id;
    await NotificationService().removeToken();
    await _client.from('user_cards').delete().eq('user_id', userId);
    // Delete conversations (messages cascade via ON DELETE CASCADE on conversation_id)
    await _client
        .from('conversations')
        .delete()
        .or('user_a.eq.$userId,user_b.eq.$userId');
    await _client.from('profiles').delete().eq('user_id', userId);
    await _client.rpc('delete_user');
    await _client.auth.signOut();
  }

  Future<void> resendVerificationEmail(String email,
      {String? captchaToken}) async {
    await _client.auth.resend(
      type: OtpType.emailChange,
      email: email,
      captchaToken: captchaToken,
    );
  }

  bool get isEmailVerified =>
      _client.auth.currentUser?.emailConfirmedAt != null;

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  User? get currentUser => _client.auth.currentUser;

  bool get isAnonymous => _client.auth.currentUser?.isAnonymous ?? false;

  bool get isGoogleLinked =>
      _client.auth.currentUser?.identities
          ?.any((id) => id.provider == 'google') ??
      false;

  Future<AuthResponse> linkGoogleAccount() async {
    final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';
    final googleUser =
        await GoogleSignIn(serverClientId: webClientId).signIn();
    if (googleUser == null) throw Exception('Google sign-in was cancelled');
    final idToken = (await googleUser.authentication).idToken;
    if (idToken == null) throw Exception('Failed to get ID token');

    final oldUserId = _client.auth.currentUser?.id;

    final response = await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );

    // If Supabase created a new user instead of linking to the anonymous one,
    // migrate all data (profile, cards, conversations) to the new user ID.
    final newUserId = response.user?.id;
    if (oldUserId != null && newUserId != null && oldUserId != newUserId) {
      await _migrateUserData(oldUserId, newUserId);
    }

    return response;
  }

  Future<void> _migrateUserData(String oldId, String newId) async {
    await _client
        .from('profiles')
        .update({'user_id': newId})
        .eq('user_id', oldId);
    await _client
        .from('user_cards')
        .update({'user_id': newId})
        .eq('user_id', oldId);
    await _client
        .from('conversations')
        .update({'user_a': newId})
        .eq('user_a', oldId);
    await _client
        .from('conversations')
        .update({'user_b': newId})
        .eq('user_b', oldId);
  }

  Future<AuthResponse> signInWithGoogle() async {
    final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';
    final googleUser =
        await GoogleSignIn(serverClientId: webClientId).signIn();
    if (googleUser == null) throw Exception('Google sign-in was cancelled');
    final idToken = (await googleUser.authentication).idToken;
    if (idToken == null) throw Exception('Failed to get ID token');
    return await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
  }
}
