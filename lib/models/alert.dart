class Alert {
  final String id;
  final String userId;
  final String issueId;
  final double distanceKm;
  final String alertType;
  final String title;
  final String message;
  final DateTime createdAt;
  final DateTime? seenAt;
  final DateTime? clickedAt;

  Alert({
    required this.id,
    required this.userId,
    required this.issueId,
    required this.distanceKm,
    required this.alertType,
    required this.title,
    required this.message,
    required this.createdAt,
    this.seenAt,
    this.clickedAt,
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id'],
      userId: json['user_id'],
      issueId: json['issue_id'],
      distanceKm: json['distance_km'].toDouble(),
      alertType: json['alert_type'],
      title: json['title'],
      message: json['message'],
      createdAt: DateTime.parse(json['created_at']),
      seenAt: json['seen_at'] != null ? DateTime.parse(json['seen_at']) : null,
      clickedAt: json['clicked_at'] != null
          ? DateTime.parse(json['clicked_at'])
          : null,
    );
  }

  bool get isUnread => seenAt == null;
}
