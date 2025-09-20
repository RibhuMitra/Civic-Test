import 'package:flutter/material.dart';

class AppConstants {
  // App Info
  static const String appName = 'Civic Issue Reporter';
  static const String appVersion = '1.0.0';

  // API Configuration
  static const int apiTimeout = 30; // seconds
  static const int maxRetries = 3;

  // Location Settings
  static const double defaultVotingRadius = 5.0; // km
  static const double defaultAlertRadius = 5.0; // km
  static const double maxAlertRadius = 20.0; // km

  // Image Settings
  static const int imageQuality = 70; // 0-100
  static const double maxImageSize = 5.0; // MB

  // Pagination
  static const int itemsPerPage = 20;

  // Cache Duration
  static const Duration cacheExpiry = Duration(hours: 1);

  // Issue Categories
  static const List<Map<String, dynamic>> issueCategories = [
    {'value': 'pothole', 'label': 'Pothole', 'icon': '🕳️'},
    {'value': 'streetlight', 'label': 'Street Light', 'icon': '💡'},
    {'value': 'garbage', 'label': 'Garbage', 'icon': '🗑️'},
    {'value': 'water', 'label': 'Water Issue', 'icon': '💧'},
    {'value': 'traffic', 'label': 'Traffic', 'icon': '🚦'},
    {'value': 'graffiti', 'label': 'Graffiti', 'icon': '🎨'},
    {'value': 'sidewalk', 'label': 'Sidewalk', 'icon': '🚶'},
    {'value': 'tree', 'label': 'Tree Issue', 'icon': '🌳'},
    {'value': 'noise', 'label': 'Noise', 'icon': '🔊'},
    {'value': 'other', 'label': 'Other', 'icon': '📍'},
  ];

  // Issue Priorities
  static const List<Map<String, dynamic>> issuePriorities = [
    {
      'value': 'low',
      'label': 'Low',
      'color': Colors.green,
      'emoji': '🟢',
    },
    {
      'value': 'normal',
      'label': 'Normal',
      'color': Colors.orange,
      'emoji': '🟡',
    },
    {
      'value': 'high',
      'label': 'High',
      'color': Colors.deepOrange,
      'emoji': '🟠',
    },
    {
      'value': 'urgent',
      'label': 'Urgent',
      'color': Colors.red,
      'emoji': '🔴',
    },
  ];

  // Issue Statuses
  static const List<Map<String, dynamic>> issueStatuses = [
    {
      'value': 'open',
      'label': 'Open',
      'color': Colors.blue,
      'icon': '📍',
    },
    {
      'value': 'in_progress',
      'label': 'In Progress',
      'color': Colors.orange,
      'icon': '🔧',
    },
    {
      'value': 'resolved',
      'label': 'Resolved',
      'color': Colors.green,
      'icon': '✅',
    },
    {
      'value': 'closed',
      'label': 'Closed',
      'color': Colors.grey,
      'icon': '🔒',
    },
  ];

  // Error Messages
  static const String genericError = 'Something went wrong. Please try again.';
  static const String networkError = 'Please check your internet connection.';
  static const String locationError = 'Unable to get your location.';
  static const String authError =
      'Authentication failed. Please sign in again.';

  // Success Messages
  static const String issueReportedSuccess = 'Issue reported successfully!';
  static const String voteSuccess = 'Your vote has been recorded!';
  static const String settingsUpdatedSuccess = 'Settings updated successfully!';
}
