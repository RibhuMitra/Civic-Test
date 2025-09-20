import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/alert_service.dart';
import '../services/location_service.dart';
import 'auth/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authService = AuthService();
  final _alertService = AlertService();
  final _locationService = LocationService();

  bool _alertsEnabled = true;
  bool _pushEnabled = true;
  bool _locationSharingEnabled = true;
  int _maxDistanceKm = 5;
  TimeOfDay? _quietStartTime;
  TimeOfDay? _quietEndTime;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    // Load preferences from database
    // This would typically fetch from notification_preferences table
  }

  Future<void> _updatePreferences() async {
    setState(() => _isLoading = true);

    try {
      await _alertService.updateNotificationPreferences(
        alertsEnabled: _alertsEnabled,
        pushEnabled: _pushEnabled,
        maxDistanceKm: _maxDistanceKm,
        quietHoursStart: _quietStartTime,
        quietHoursEnd: _quietEndTime,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectQuietTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? _quietStartTime ?? const TimeOfDay(hour: 22, minute: 0)
          : _quietEndTime ?? const TimeOfDay(hour: 7, minute: 0),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _quietStartTime = picked;
        } else {
          _quietEndTime = picked;
        }
      });
    }
  }

  Future<void> _handleSignOut() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _authService.signOut();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Scaffold(
      body: ListView(
        children: [
          // User Profile Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.blue,
                  child: Text(
                    user?.email?.substring(0, 1).toUpperCase() ?? 'U',
                    style: const TextStyle(fontSize: 32, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.email ?? 'User',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'Member since ${_formatDate(user?.createdAt as DateTime?)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),

          // Notification Settings
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Notifications',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),

          SwitchListTile(
            title: const Text('Enable Alerts'),
            subtitle: const Text('Receive alerts for nearby issues'),
            value: _alertsEnabled,
            onChanged: (value) {
              setState(() => _alertsEnabled = value);
            },
          ),

          SwitchListTile(
            title: const Text('Push Notifications'),
            subtitle: const Text('Receive push notifications on your device'),
            value: _pushEnabled,
            onChanged: _alertsEnabled
                ? (value) {
                    setState(() => _pushEnabled = value);
                  }
                : null,
          ),

          ListTile(
            title: const Text('Alert Radius'),
            subtitle: Text('Get alerts for issues within $_maxDistanceKm km'),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: _maxDistanceKm.toDouble(),
                min: 1,
                max: 20,
                divisions: 19,
                label: '$_maxDistanceKm km',
                onChanged: _alertsEnabled
                    ? (value) {
                        setState(() => _maxDistanceKm = value.round());
                      }
                    : null,
              ),
            ),
          ),

          ListTile(
            title: const Text('Quiet Hours'),
            subtitle: Text(
              _quietStartTime != null && _quietEndTime != null
                  ? '${_quietStartTime!.format(context)} - ${_quietEndTime!.format(context)}'
                  : 'No quiet hours set',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed:
                      _alertsEnabled ? () => _selectQuietTime(true) : null,
                  child: const Text('Start'),
                ),
                TextButton(
                  onPressed:
                      _alertsEnabled ? () => _selectQuietTime(false) : null,
                  child: const Text('End'),
                ),
              ],
            ),
          ),

          const Divider(),

          // Location Settings
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Location',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),

          SwitchListTile(
            title: const Text('Share Location'),
            subtitle: const Text('Allow the app to use your location'),
            value: _locationSharingEnabled,
            onChanged: (value) async {
              if (value) {
                final granted =
                    await _locationService.requestLocationPermission();
                if (granted) {
                  setState(() => _locationSharingEnabled = true);
                  await _locationService.updateUserLocation();
                }
              } else {
                setState(() => _locationSharingEnabled = false);
              }
            },
          ),

          ListTile(
            title: const Text('Update Location'),
            subtitle: const Text('Manually update your current location'),
            leading: const Icon(Icons.my_location),
            onTap: () async {
              await _locationService.updateUserLocation();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Location updated'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
          ),

          const Divider(),

          // App Settings
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'App',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),

          ListTile(
            title: const Text('Privacy Policy'),
            leading: const Icon(Icons.privacy_tip),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Open privacy policy
            },
          ),

          ListTile(
            title: const Text('Terms of Service'),
            leading: const Icon(Icons.description),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Open terms of service
            },
          ),

          ListTile(
            title: const Text('About'),
            leading: const Icon(Icons.info),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Civic Issue Reporter',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2024 Civic Tech',
              );
            },
          ),

          const Divider(),

          // Save Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _updatePreferences,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Save Settings'),
            ),
          ),

          // Sign Out Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton(
              onPressed: _handleSignOut,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Sign Out'),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return '${date.month}/${date.year}';
  }
}
