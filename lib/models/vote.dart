class Vote {
  final String id;
  final String issueId;
  final String userId;
  final DateTime createdAt;

  Vote({
    required this.id,
    required this.issueId,
    required this.userId,
    required this.createdAt,
  });

  factory Vote.fromJson(Map<String, dynamic> json) {
    return Vote(
      id: json['id'],
      issueId: json['issue_id'],
      userId: json['user_id'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'issue_id': issueId,
      'user_id': userId,
    };
  }
}
