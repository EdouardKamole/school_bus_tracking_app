// lib/screens/live_bus_tracking_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:school_bus_tracking_app/screens/bus_details_screen.dart';
import 'package:firebase_database/firebase_database.dart';

class LiveBusTrackingScreen extends StatefulWidget {
  const LiveBusTrackingScreen({Key? key}) : super(key: key);

  @override
  _LiveBusTrackingScreenState createState() => _LiveBusTrackingScreenState();
}

class _LiveBusTrackingScreenState extends State<LiveBusTrackingScreen>
    with SingleTickerProviderStateMixin {
  LatLng studentLocation = const LatLng(24.7136, 46.6753); // Default fallback
  LatLng busLocation = const LatLng(24.7236, 46.6853); // Default fallback
  String arrivalTime = '10 min';
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final String studentName = 'Mohammed Ali'; // Hardcoded to match main.dart
  late AnimationController _animationController;
  late Animation<double> _animation;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _fetchStudentLocation();
    _fetchBusLocation();
    // Initialize animation controller for marker pulse effect
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Fetch student location from Firebase Realtime Database
  void _fetchStudentLocation() {
    _database
        .child('students')
        .child(studentName)
        .child('status')
        .onValue
        .listen(
          (event) {
            if (event.snapshot.exists) {
              final data = event.snapshot.value as Map<dynamic, dynamic>;
              final latitude = data['latitude'] as double?;
              final longitude = data['longitude'] as double?;
              if (latitude != null && longitude != null) {
                setState(() {
                  studentLocation = LatLng(latitude, longitude);
                });
              }
            } else {
              print('No location data found for $studentName');
            }
          },
          onError: (error) {
            print('Error fetching student location: $error');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Failed to fetch student location from database.',
                ),
              ),
            );
          },
        );
  }

  // Fetch bus location from Firebase Realtime Database
  void _fetchBusLocation() {
    _database
        .child('buses')
        .child('bus1')
        .child('location')
        .onValue
        .listen(
          (event) {
            if (event.snapshot.exists) {
              final data = event.snapshot.value as Map<dynamic, dynamic>;
              final latitude = data['latitude'] as double?;
              final longitude = data['longitude'] as double?;
              if (latitude != null && longitude != null) {
                setState(() {
                  busLocation = LatLng(latitude, longitude);
                });
              }
            } else {
              print('No location data found for bus1');
            }
          },
          onError: (error) {
            print('Error fetching bus location: $error');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to fetch bus location from database.'),
              ),
            );
          },
        );
  }

  // Calculate center point between student and bus locations
  LatLng _calculateCenterPoint() {
    final double centerLat =
        (studentLocation.latitude + busLocation.latitude) / 2;
    final double centerLon =
        (studentLocation.longitude + busLocation.longitude) / 2;
    return LatLng(centerLat, centerLon);
  }

  // Zoom in on the map
  void _zoomIn() {
    _mapController.move(_mapController.center, _mapController.zoom + 1);
  }

  // Zoom out on the map
  void _zoomOut() {
    _mapController.move(_mapController.center, _mapController.zoom - 1);
  }

  // Center map on student location
  void _centerOnStudent() {
    _mapController.move(studentLocation, _mapController.zoom);
  }

  // Center map on bus location
  void _centerOnBus() {
    _mapController.move(busLocation, _mapController.zoom);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Bus Tracking')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(center: _calculateCenterPoint(), zoom: 14),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: studentLocation,
                    width: 40,
                    height: 40,
                    child: ScaleTransition(
                      scale: _animation,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person_pin_circle,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  Marker(
                    point: busLocation,
                    width: 40,
                    height: 40,
                    child: ScaleTransition(
                      scale: _animation,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.directions_bus,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: _buildArrivalInfoCard(),
          ),
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.my_location, color: Colors.blue),
                onPressed: _centerOnStudent,
                tooltip: 'Center on My Location',
              ),
            ),
          ),
          Positioned(
            top: 76,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.directions_bus, color: Colors.red),
                onPressed: _centerOnBus,
                tooltip: 'Center on Bus Location',
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'zoomIn',
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add, color: Colors.black),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'zoomOut',
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove, color: Colors.black),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.directions_bus),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => BusDetailsScreen()),
          );
        },
      ),
    );
  }

  Widget _buildArrivalInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bus Arrival Time',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              arrivalTime,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: 0.3, // Replace with actual progress
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          ],
        ),
      ),
    );
  }
}
