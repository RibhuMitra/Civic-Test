class Issue {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String? imageUrl;
  final double latitude;
  final double longitude;
  final String? address;
  final String status;
  final String priority;
  final String? category;
  final int votesCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool? hasVoted;
  final double? distanceKm;

  Issue({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.latitude,
    required this.longitude,
    this.address,
    this.status = 'open',
    this.priority = 'normal',
    this.category,
    this.votesCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.hasVoted,
    this.distanceKm,
  });

  factory Issue.fromJson(Map<String, dynamic> json) {
    return Issue(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
      description: json['description'],
      imageUrl: json['image_url'],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      address: json['address'],
      status: json['status'] ?? 'open',
      priority: json['priority'] ?? 'normal',
      category: json['category'],
      votesCount: json['votes_count'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      hasVoted: json['has_voted'],
      distanceKm: json['distance_km']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'status': status,
      'priority': priority,
      'category': category,
    };
  }

  String get priorityEmoji {
    switch (priority) {
      case 'urgent':
        return '🔴';
      case 'high':
        return '🟠';
      case 'normal':
        return '🟡';
      case 'low':
        return '🟢';
      default:
        return '⚪';
    }
  }

  String get statusIcon {
    switch (status) {
      case 'resolved':
        return '✅';
      case 'in_progress':
        return '🔧';
      default:
        return '📍';
    }
  }
}
