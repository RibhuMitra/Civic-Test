// lib/services/location_service.dart
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'supabase_service.dart';

class LocationService {
  final _supabase = SupabaseService.client;

  Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status == PermissionStatus.granted;
  }

  Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  Future<void> updateUserLocation() async {
    try {
      final position = await getCurrentLocation();
      if (position != null) {
        final userId = _supabase.auth.currentUser?.id;
        if (userId != null) {
          await _supabase.from('user_locations').upsert({
            'user_id': userId,
            'latitude': position.latitude,
            'longitude': position.longitude,
            'accuracy': position.accuracy,
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
      }
    } catch (e) {
      print('Error updating user location: $e');
    }
  }

  Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return '${place.street}, ${place.locality}, ${place.administrativeArea}';
      }
    } catch (e) {
      print('Error getting address: $e');
    }
    return null;
  }

  double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) /
        1000; // Convert to km
  }
}
