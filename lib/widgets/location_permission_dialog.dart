import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationPermissionDialog extends StatelessWidget {
  final VoidCallback onPermissionGranted;
  final VoidCallback? onPermissionDenied;

  const LocationPermissionDialog({
    super.key,
    required this.onPermissionGranted,
    this.onPermissionDenied,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.location_on, color: Colors.blue, size: 28),
          SizedBox(width: 8),
          Text('Location Permission'),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This app needs your location to:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('Report issues at your exact location'),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('Vote on issues within 5km of you'),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('Get alerts for nearby issues'),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            'Your location data is only used for app features and is never shared with third parties.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onPermissionDenied?.call();
          },
          child: const Text('Not Now'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            final status = await Permission.location.request();

            if (status == PermissionStatus.granted) {
              onPermissionGranted();
            } else if (status == PermissionStatus.permanentlyDenied) {
              // Show settings dialog
              _showSettingsDialog(context);
            } else {
              onPermissionDenied?.call();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: const Text('Allow Location'),
        ),
      ],
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'Location permission has been permanently denied. '
          'Please enable it in your device settings to use this feature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onPermissionGranted,
    VoidCallback? onPermissionDenied,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => LocationPermissionDialog(
        onPermissionGranted: onPermissionGranted,
        onPermissionDenied: onPermissionDenied,
      ),
    );
  }
}
