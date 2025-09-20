import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/alert.dart';
import 'supabase_client.dart';

class AlertService {
  final _supabase = SupabaseClient.client;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initializePushNotifications() async {
    // Request permission
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get FCM token
    String? token = await _firebaseMessaging.getToken();
    if (token != null) {
      await _saveDeviceToken(token);
    }

    // Listen to token refresh
    _firebaseMessaging.onTokenRefresh.listen(_saveDeviceToken);

    // Initialize local notifications
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background message taps
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
  }

  Future<void> _saveDeviceToken(String token) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        // Get existing tokens
        final response = await _supabase
            .from('notification_preferences')
            .select('device_tokens')
            .eq('user_id', userId)
            .maybeSingle();

        List<dynamic> tokens = [];
        if (response != null && response['device_tokens'] != null) {
          tokens = List.from(response['device_tokens']);
        }

        // Add token if not exists
        if (!tokens.contains(token)) {
          tokens.add(token);

          await _supabase.from('notification_preferences').upsert({
            'user_id': userId,
            'device_tokens': tokens,
          });
        }
      }
    } catch (e) {
      print('Error saving device token: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    _showLocalNotification(
      title: message.notification?.title ?? 'New Alert',
      body: message.notification?.body ?? '',
      payload: message.data['issue_id'],
    );
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    // Navigate to issue detail
    final issueId = message.data['issue_id'];
    if (issueId != null) {
      // Handle navigation
    }
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'civic_alerts',
      'Civic Alerts',
      channelDescription: 'Notifications for nearby civic issues',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
      payload: payload,
    );
  }

  void _handleNotificationTap(NotificationResponse response) {
    // Handle notification tap
    final issueId = response.payload;
    if (issueId != null) {
      // Navigate to issue detail
    }
  }

  Future<List<Alert>> getAlerts({bool unreadOnly = false}) async {
    try {
      var query = _supabase
          .from('alerts')
          .select()
          .eq('user_id', _supabase.auth.currentUser!.id)
          .order('created_at', ascending: false);

      if (unreadOnly) {
        query = query.isFilter('seen_at', null);
      }

      final response = await query;
      return (response as List).map((json) => Alert.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load alerts: $e');
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final response = await _supabase
          .from('alerts')
          .select('id')
          .eq('user_id', _supabase.auth.currentUser!.id)
          .isFilter('seen_at', null);

      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  Future<void> markAlertAsRead(String alertId) async {
    try {
      await _supabase.from('alerts').update(
          {'seen_at': DateTime.now().toIso8601String()}).eq('id', alertId);
    } catch (e) {
      print('Error marking alert as read: $e');
    }
  }

  Future<void> markAllAlertsAsRead() async {
    try {
      await _supabase
          .from('alerts')
          .update({'seen_at': DateTime.now().toIso8601String()})
          .eq('user_id', _supabase.auth.currentUser!.id)
          .isFilter('seen_at', null);
    } catch (e) {
      print('Error marking all alerts as read: $e');
    }
  }

  Stream<List<Alert>> getAlertsStream() {
    return _supabase
        .from('alerts')
        .stream(primaryKey: ['id'])
        .eq('user_id', _supabase.auth.currentUser!.id)
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => Alert.fromJson(json)).toList());
  }

  Future<void> updateNotificationPreferences({
    bool? alertsEnabled,
    bool? pushEnabled,
    int? maxDistanceKm,
    TimeOfDay? quietHoursStart,
    TimeOfDay? quietHoursEnd,
  }) async {
    try {
      final updates = <String, dynamic>{};

      if (alertsEnabled != null) updates['alerts_enabled'] = alertsEnabled;
      if (pushEnabled != null) updates['push_enabled'] = pushEnabled;
      if (maxDistanceKm != null) updates['max_distance_km'] = maxDistanceKm;
      if (quietHoursStart != null) {
        updates['quiet_hours_start'] =
            '${quietHoursStart.hour.toString().padLeft(2, '0')}:${quietHoursStart.minute.toString().padLeft(2, '0')}:00';
      }
      if (quietHoursEnd != null) {
        updates['quiet_hours_end'] =
            '${quietHoursEnd.hour.toString().padLeft(2, '0')}:${quietHoursEnd.minute.toString().padLeft(2, '0')}:00';
      }

      await _supabase
          .from('notification_preferences')
          .update(updates)
          .eq('user_id', _supabase.auth.currentUser!.id);
    } catch (e) {
      throw Exception('Failed to update preferences: $e');
    }
  }
}
