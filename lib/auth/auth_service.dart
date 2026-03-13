import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  User? get currentUser => _client.auth.currentUser;
}
