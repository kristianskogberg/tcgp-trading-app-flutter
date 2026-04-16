import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tcgp_trading_app/models/feedback_submission.dart';

class FeedbackService {
  static final FeedbackService _instance = FeedbackService._internal();
  factory FeedbackService() => _instance;
  FeedbackService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  Future<void> submitFeedback({
    required FeedbackType type,
    String? description,
    String? cardId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Not authenticated');
    final info = await PackageInfo.fromPlatform();
    final trimmedDescription =
        description?.trim().isEmpty == true ? null : description?.trim();

    await _client.from('feedback').insert({
      'user_id': userId,
      'type': type.value,
      'description': trimmedDescription,
      'app_version': '${info.version}+${info.buildNumber}',
      'platform': defaultTargetPlatform.name.toLowerCase(),
      if (cardId != null) 'card_id': cardId,
    });
  }
}
