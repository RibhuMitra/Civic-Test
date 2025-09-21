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
      // Build query step by step without storing intermediate variables
      final response = await _supabase
          .from('issues')
          .select('*')
          .order(sortBy!, ascending: !descending);

      final currentUserId = _supabase.auth.currentUser?.id;

      // Get votes separately to avoid complex joins
      List<Issue> issues = [];

      for (final json in (response as List)) {
        // Check if current user has voted on this issue
        bool hasVoted = false;
        if (currentUserId != null) {
          try {
            final voteResponse = await _supabase
                .from('votes')
                .select('id')
                .eq('issue_id', json['id'])
                .eq('user_id', currentUserId)
                .maybeSingle();

            hasVoted = voteResponse != null;
          } catch (e) {
            // If vote check fails, assume not voted
            hasVoted = false;
          }
        }

        // Calculate distance if user location provided
        double? distanceKm;
        if (userLat != null && userLon != null) {
          distanceKm = _locationService.calculateDistance(
            userLat,
            userLon,
            json['latitude'].toDouble(),
            json['longitude'].toDouble(),
          );

          // Skip if outside max distance
          if (maxDistanceKm != null && distanceKm > maxDistanceKm) {
            continue;
          }
        }

        // Add calculated fields to json
        json['has_voted'] = hasVoted;
        if (distanceKm != null) {
          json['distance_km'] = distanceKm;
        }

        issues.add(Issue.fromJson(json));
      }

      // Sort by distance if user location provided
      if (userLat != null && userLon != null && sortBy == 'distance') {
        issues.sort((a, b) {
          final distA = a.distanceKm ?? double.infinity;
          final distB = b.distanceKm ?? double.infinity;
          return descending ? distB.compareTo(distA) : distA.compareTo(distB);
        });
      }

      return issues;
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
      final response =
          await _supabase.from('issues').select('*').eq('id', id).single();

      final currentUserId = _supabase.auth.currentUser?.id;
      bool hasVoted = false;

      // Check if current user has voted
      if (currentUserId != null) {
        try {
          final voteResponse = await _supabase
              .from('votes')
              .select('id')
              .eq('issue_id', id)
              .eq('user_id', currentUserId)
              .maybeSingle();

          hasVoted = voteResponse != null;
        } catch (e) {
          hasVoted = false;
        }
      }

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

  // Helper method to get issues near a location
  Future<List<Issue>> getNearbyIssues({
    required double userLat,
    required double userLon,
    double maxDistanceKm = 5.0,
    String sortBy = 'distance',
  }) async {
    return getIssues(
      userLat: userLat,
      userLon: userLon,
      maxDistanceKm: maxDistanceKm,
      sortBy: sortBy,
    );
  }

  // Helper method to get issues by category
  Future<List<Issue>> getIssuesByCategory(String category) async {
    try {
      final response = await _supabase
          .from('issues')
          .select('*')
          .eq('category', category)
          .order('created_at', ascending: false);

      return (response as List).map((json) => Issue.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load issues by category: $e');
    }
  }

  // Helper method to get issues by status
  Future<List<Issue>> getIssuesByStatus(String status) async {
    try {
      final response = await _supabase
          .from('issues')
          .select('*')
          .eq('status', status)
          .order('created_at', ascending: false);

      return (response as List).map((json) => Issue.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load issues by status: $e');
    }
  }

  // Helper method to get user's own issues
  Future<List<Issue>> getUserIssues({String? userId}) async {
    try {
      final targetUserId = userId ?? _supabase.auth.currentUser?.id;
      if (targetUserId == null) {
        throw Exception('No user ID provided');
      }

      final response = await _supabase
          .from('issues')
          .select('*')
          .eq('user_id', targetUserId)
          .order('created_at', ascending: false);

      return (response as List).map((json) => Issue.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load user issues: $e');
    }
  }

  // Helper method to search issues by title or description
  Future<List<Issue>> searchIssues(String searchTerm) async {
    try {
      final response = await _supabase
          .from('issues')
          .select('*')
          .or('title.ilike.%$searchTerm%,description.ilike.%$searchTerm%')
          .order('created_at', ascending: false);

      return (response as List).map((json) => Issue.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to search issues: $e');
    }
  }

  // Get issue statistics
  Future<Map<String, dynamic>> getIssueStats() async {
    try {
      // Get total count
      final totalResponse = await _supabase.from('issues').select('id');
      final totalCount = (totalResponse as List).length;

      // Get counts by status
      final openResponse =
          await _supabase.from('issues').select('id').eq('status', 'open');
      final openCount = (openResponse as List).length;

      final resolvedResponse =
          await _supabase.from('issues').select('id').eq('status', 'resolved');
      final resolvedCount = (resolvedResponse as List).length;

      final inProgressResponse = await _supabase
          .from('issues')
          .select('id')
          .eq('status', 'in_progress');
      final inProgressCount = (inProgressResponse as List).length;

      return {
        'total': totalCount,
        'open': openCount,
        'resolved': resolvedCount,
        'in_progress': inProgressCount,
        'closed': totalCount - openCount - resolvedCount - inProgressCount,
      };
    } catch (e) {
      throw Exception('Failed to get issue statistics: $e');
    }
  }
}
