// lib/services/issue_service.dart
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/issue.dart';
import 'supabase_service.dart';
import 'location_service.dart';

class IssueService {
  final _supabase = SupabaseService.client;
  final _locationService = LocationService();

  Future<List<Issue>> getIssues({
    String? sortBy = 'created_at',
    bool descending = true,
    double? userLat,
    double? userLon,
    double? maxDistanceKm,
  }) async {
    try {
      var query = _supabase.from('issues').select('*, votes(user_id)');

      // Add distance filter if location provided
      if (userLat != null && userLon != null && maxDistanceKm != null) {
        query = query.rpc('get_nearby_issues', params: {
          'user_lat': userLat,
          'user_lon': userLon,
          'max_distance': maxDistanceKm,
        });
      }

      // Add sorting
      query = query.order(sortBy!, ascending: !descending);

      final response = await query;

      final currentUserId = _supabase.auth.currentUser?.id;

      return (response as List).map((json) {
        // Check if current user has voted
        final votes = json['votes'] as List?;
        final hasVoted =
            votes?.any((v) => v['user_id'] == currentUserId) ?? false;

        json['has_voted'] = hasVoted;
        return Issue.fromJson(json);
      }).toList();
    } catch (e) {
      throw Exception('Failed to load issues: $e');
    }
  }

  Future<Issue> createIssue({
    required String title,
    required String description,
    required double latitude,
    required double longitude,
    String? address,
    String? category,
    String priority = 'normal',
    XFile? image,
  }) async {
    try {
      String? imageUrl;

      // Upload image if provided
      if (image != null) {
        imageUrl = await _uploadImage(image);
      }

      // Get address if not provided
      address ??= await _locationService.getAddressFromCoordinates(
        latitude,
        longitude,
      );

      final response = await _supabase
          .from('issues')
          .insert({
            'user_id': _supabase.auth.currentUser!.id,
            'title': title,
            'description': description,
            'image_url': imageUrl,
            'latitude': latitude,
            'longitude': longitude,
            'address': address,
            'category': category,
            'priority': priority,
          })
          .select()
          .single();

      return Issue.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create issue: $e');
    }
  }

  Future<String> _uploadImage(XFile image) async {
    try {
      final bytes = await image.readAsBytes();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      final path = 'issues/$fileName';

      await _supabase.storage.from('issue-images').uploadBinary(path, bytes);

      return _supabase.storage.from('issue-images').getPublicUrl(path);
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  Future<Issue> getIssueById(String id) async {
    try {
      final response = await _supabase
          .from('issues')
          .select('*, votes(user_id)')
          .eq('id', id)
          .single();

      final currentUserId = _supabase.auth.currentUser?.id;
      final votes = response['votes'] as List?;
      final hasVoted =
          votes?.any((v) => v['user_id'] == currentUserId) ?? false;

      response['has_voted'] = hasVoted;
      return Issue.fromJson(response);
    } catch (e) {
      throw Exception('Failed to load issue: $e');
    }
  }

  Future<void> updateIssueStatus(String issueId, String status) async {
    try {
      await _supabase
          .from('issues')
          .update({'status': status}).eq('id', issueId);
    } catch (e) {
      throw Exception('Failed to update issue status: $e');
    }
  }

  Stream<List<Issue>> getIssuesStream() {
    return _supabase
        .from('issues')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => Issue.fromJson(json)).toList());
  }
}
