import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> saveProfile({
    required String username,
    required String friendId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    // logging
    print(
        'Saving profile for user: ${user.id}, username: $username, friendId: $friendId');

    await _client.from('profiles').upsert({
      'user_id': user.id,
      'username': username,
      'friend_id': friendId,
    });
  }
}
