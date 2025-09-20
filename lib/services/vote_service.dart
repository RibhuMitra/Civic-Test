import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';
import 'location_service.dart';

class VoteService {
  final _supabase = SupabaseClient.client;
  final _locationService = LocationService();

  Future<Map<String, dynamic>> voteOnIssue(String issueId) async {
    try {
      // Get current location
      final position = await _locationService.getCurrentLocation();
      if (position == null) {
        return {
          'success': false,
          'error':
              'Unable to get your location. Please enable location services.',
        };
      }

      // Call vote function
      final response = await _supabase.rpc('vote_issue', params: {
        'p_issue_id': issueId,
        'p_user_id': _supabase.auth.currentUser!.id,
        'p_user_lat': position.latitude,
        'p_user_lon': position.longitude,
      });

      return response as Map<String, dynamic>;
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to vote: $e',
      };
    }
  }

  Future<bool> hasUserVoted(String issueId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('votes')
          .select('id')
          .eq('issue_id', issueId)
          .eq('user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking vote status: $e');
      return false;
    }
  }

  Future<int> getVoteCount(String issueId) async {
    try {
      final response = await _supabase
          .from('issues')
          .select('votes_count')
          .eq('id', issueId)
          .single();

      return response['votes_count'] ?? 0;
    } catch (e) {
      print('Error getting vote count: $e');
      return 0;
    }
  }

  Stream<int> getVoteCountStream(String issueId) {
    return _supabase
        .from('issues')
        .stream(primaryKey: ['id'])
        .eq('id', issueId)
        .map((data) => data.isNotEmpty ? data.first['votes_count'] ?? 0 : 0);
  }
}
