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
    await NotificationService().removeToken();
    await Supabase.instance.client.from('user_cards').delete().eq(
          'user_id',
          _client.auth.currentUser!.id,
        );
    await Supabase.instance.client.from('profiles').delete().eq(
          'user_id',
          _client.auth.currentUser!.id,
        );
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
}
