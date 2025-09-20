import 'dart:math' as math;

class DistanceCalculator {
  // Earth's radius in kilometers
  static const double earthRadiusKm = 6371.0;

  /// Calculate distance between two coordinates using Haversine formula
  /// Returns distance in kilometers
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    // Convert degrees to radians
    final lat1Rad = _degreesToRadians(lat1);
    final lat2Rad = _degreesToRadians(lat2);
    final deltaLatRad = _degreesToRadians(lat2 - lat1);
    final deltaLonRad = _degreesToRadians(lon2 - lon1);

    // Haversine formula
    final a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLonRad / 2) *
            math.sin(deltaLonRad / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusKm * c;
  }

  /// Convert degrees to radians
  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  /// Convert radians to degrees
  static double _radiansToDegrees(double radians) {
    return radians * (180 / math.pi);
  }

  /// Check if a point is within radius of another point
  static bool isWithinRadius(
    double centerLat,
    double centerLon,
    double pointLat,
    double pointLon,
    double radiusKm,
  ) {
    final distance = calculateDistance(
      centerLat,
      centerLon,
      pointLat,
      pointLon,
    );

    return distance <= radiusKm;
  }

  /// Format distance for display
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} m';
    } else if (distanceKm < 10) {
      return '${distanceKm.toStringAsFixed(1)} km';
    } else {
      return '${distanceKm.round()} km';
    }
  }

  /// Calculate bearing between two points
  static double calculateBearing(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final lat1Rad = _degreesToRadians(lat1);
    final lat2Rad = _degreesToRadians(lat2);
    final deltaLonRad = _degreesToRadians(lon2 - lon1);

    final x = math.sin(deltaLonRad) * math.cos(lat2Rad);
    final y = math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(deltaLonRad);

    final bearing = math.atan2(x, y);

    return (_radiansToDegrees(bearing) + 360) % 360;
  }

  /// Get compass direction from bearing
  static String getCompassDirection(double bearing) {
    const directions = [
      'N',
      'NNE',
      'NE',
      'ENE',
      'E',
      'ESE',
      'SE',
      'SSE',
      'S',
      'SSW',
      'SW',
      'WSW',
      'W',
      'WNW',
      'NW',
      'NNW'
    ];

    final index = ((bearing + 11.25) / 22.5).floor() % 16;
    return directions[index];
  }

  /// Get bounding box for a given center point and radius
  static Map<String, double> getBoundingBox(
    double centerLat,
    double centerLon,
    double radiusKm,
  ) {
    // Convert radius to degrees
    final latDelta = radiusKm / 111.0; // 1 degree latitude ≈ 111 km
    final lonDelta =
        radiusKm / (111.0 * math.cos(_degreesToRadians(centerLat)));

    return {
      'minLat': centerLat - latDelta,
      'maxLat': centerLat + latDelta,
      'minLon': centerLon - lonDelta,
      'maxLon': centerLon + lonDelta,
    };
  }
}
