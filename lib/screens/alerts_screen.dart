import 'package:flutter/material.dart';
import '../models/alert.dart';
import '../services/alert_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final _alertService = AlertService();
  List<Alert> _alerts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);
    try {
      final alerts = await _alertService.getAlerts();
      setState(() => _alerts = alerts);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading alerts: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllAsRead() async {
    await _alertService.markAllAlertsAsRead();
    _loadAlerts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header with mark all as read
          if (_alerts.any((a) => a.isUnread))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: _markAllAsRead,
                    icon: const Icon(Icons.done_all),
                    label: const Text('Mark all as read'),
                  ),
                ],
              ),
            ),

          // Alerts list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadAlerts,
                    child: _alerts.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.notifications_none,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No alerts yet',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _alerts.length,
                            itemBuilder: (context, index) {
                              final alert = _alerts[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: alert.isUnread
                                      ? Colors.blue
                                      : Colors.grey[300],
                                  child: Icon(
                                    Icons.location_on,
                                    color: alert.isUnread
                                        ? Colors.white
                                        : Colors.grey[600],
                                  ),
                                ),
                                title: Text(
                                  alert.title,
                                  style: TextStyle(
                                    fontWeight: alert.isUnread
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(alert.message),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatTime(alert.createdAt),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: alert.isUnread
                                    ? Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Colors.blue,
                                          shape: BoxShape.circle,
                                        ),
                                      )
                                    : null,
                                onTap: () async {
                                  if (alert.isUnread) {
                                    await _alertService
                                        .markAlertAsRead(alert.id);
                                    _loadAlerts();
                                  }
                                  // Navigate to issue detail
                                },
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
