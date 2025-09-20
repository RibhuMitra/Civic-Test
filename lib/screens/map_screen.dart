import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/issue.dart';
import '../services/issue_service.dart';
import '../services/location_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final _issueService = IssueService();
  final _locationService = LocationService();

  Set<Marker> _markers = {};
  List<Issue> _issues = [];
  Position? _currentPosition;
  bool _isLoading = true;

  static const CameraPosition _defaultPosition = CameraPosition(
    target: LatLng(37.7749, -122.4194), // San Francisco
    zoom: 14,
  );

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    await _loadCurrentLocation();
    await _loadIssues();
  }

  Future<void> _loadCurrentLocation() async {
    final position = await _locationService.getCurrentLocation();
    if (position != null && mounted) {
      setState(() {
        _currentPosition = position;
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          15,
        ),
      );
    }
  }

  Future<void> _loadIssues() async {
    setState(() => _isLoading = true);

    try {
      final issues = await _issueService.getIssues();

      final markers = issues.map((issue) {
        return Marker(
          markerId: MarkerId(issue.id),
          position: LatLng(issue.latitude, issue.longitude),
          infoWindow: InfoWindow(
            title: issue.title,
            snippet: '${issue.votesCount} votes • ${issue.status}',
            onTap: () => _showIssueDetails(issue),
          ),
          icon: _getMarkerIcon(issue.priority),
        );
      }).toSet();

      setState(() {
        _issues = issues;
        _markers = markers;
        _isLoading = false;
      });

      // Add current location marker
      if (_currentPosition != null) {
        setState(() {
          _markers.add(
            Marker(
              markerId: const MarkerId('current_location'),
              position: LatLng(
                  _currentPosition!.latitude, _currentPosition!.longitude),
              infoWindow: const InfoWindow(title: 'Your Location'),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueBlue),
            ),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading issues: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  BitmapDescriptor _getMarkerIcon(String priority) {
    switch (priority) {
      case 'urgent':
        return BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueViolet);
      case 'high':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      case 'normal':
        return BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange);
      case 'low':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      default:
        return BitmapDescriptor.defaultMarker;
    }
  }

  void _showIssueDetails(Issue issue) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    issue.priorityEmoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      issue.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Text(
                    issue.statusIcon,
                    style: const TextStyle(fontSize: 24),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                issue.description,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      issue.address ?? 'Unknown location',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Chip(
                    label: Text('${issue.votesCount} votes'),
                    avatar: const Icon(Icons.thumb_up, size: 16),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // Navigate to issue detail screen
                    },
                    child: const Text('View Details'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _currentPosition != null
                ? CameraPosition(
                    target: LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    ),
                    zoom: 14,
                  )
                : _defaultPosition,
            onMapCreated: (controller) {
              _mapController = controller;
            },
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Custom controls
          Positioned(
            top: 50,
            right: 16,
            child: Column(
              children: [
                // Refresh button
                FloatingActionButton.small(
                  heroTag: 'refresh',
                  onPressed: _loadIssues,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.refresh, color: Colors.black),
                ),
                const SizedBox(height: 8),

                // My location button
                FloatingActionButton.small(
                  heroTag: 'location',
                  onPressed: _loadCurrentLocation,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.my_location, color: Colors.black),
                ),
              ],
            ),
          ),

          // Issue count badge
          Positioned(
            top: 50,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(
                    '${_issues.length} issues',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
