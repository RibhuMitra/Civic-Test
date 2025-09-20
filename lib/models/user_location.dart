class UserLocation {
  final String userId;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime updatedAt;
  final bool isSharingLocation;

  UserLocation({
    required this.userId,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.updatedAt,
    this.isSharingLocation = true,
  });

  factory UserLocation.fromJson(Map<String, dynamic> json) {
    return UserLocation(
      userId: json['user_id'],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      accuracy: json['accuracy']?.toDouble(),
      updatedAt: DateTime.parse(json['updated_at']),
      isSharingLocation: json['is_sharing_location'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'updated_at': updatedAt.toIso8601String(),
      'is_sharing_location': isSharingLocation,
    };
  }
}
