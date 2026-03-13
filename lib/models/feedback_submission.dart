enum FeedbackType {
  bugReport('bug_report', 'Bug Report'),
  featureRequest('feature_request', 'Feature Request'),
  general('general', 'General Feedback');

  const FeedbackType(this.value, this.label);
  final String value;
  final String label;

  static FeedbackType fromValue(String v) =>
      FeedbackType.values.firstWhere((e) => e.value == v);
}

class FeedbackSubmission {
  final String id;
  final String userId;
  final FeedbackType type;
  final String? description;
  final String? appVersion;
  final String? platform;
  final String status;
  final DateTime createdAt;

  const FeedbackSubmission({
    required this.id,
    required this.userId,
    required this.type,
    this.description,
    this.appVersion,
    this.platform,
    required this.status,
    required this.createdAt,
  });

  factory FeedbackSubmission.fromJson(Map<String, dynamic> json) {
    return FeedbackSubmission(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: FeedbackType.fromValue(json['type'] as String),
      description: json['description'] as String?,
      appVersion: json['app_version'] as String?,
      platform: json['platform'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
