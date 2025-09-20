import 'package:flutter/material.dart';
import 'package:badges/badges.dart' as badges;
import 'issues_list_screen.dart';
import 'map_screen.dart';
import 'report_issue_screen.dart';
import 'alerts_screen.dart';
import 'settings_screen.dart';
import '../services/alert_service.dart';
import '../services/location_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final _alertService = AlertService();
  final _locationService = LocationService();
  int _unreadAlerts = 0;

  final List<Widget> _screens = [
    const IssuesListScreen(),
    const MapScreen(),
    const AlertsScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadUnreadCount();
  }

  Future<void> _initializeServices() async {
    // Request location permission
    await _locationService.requestLocationPermission();

    // Update user location
    await _locationService.updateUserLocation();

    // Listen to alert updates
    _alertService.getAlertsStream().listen((_) {
      _loadUnreadCount();
    });
  }

  Future<void> _loadUnreadCount() async {
    final count = await _alertService.getUnreadCount();
    if (mounted) {
      setState(() => _unreadAlerts = count);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Civic Issue Reporter'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _locationService.updateUserLocation();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Location updated'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.list),
            label: 'Issues',
          ),
          const NavigationDestination(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: badges.Badge(
              showBadge: _unreadAlerts > 0,
              badgeContent: Text(
                _unreadAlerts.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
              child: const Icon(Icons.notifications),
            ),
            label: 'Alerts',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReportIssueScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
