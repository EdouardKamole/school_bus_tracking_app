import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:school_bus_tracking_app/screens/bus_details_screen.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import '../eta_notifier.dart';
import 'dart:async';

class LiveBusTrackingScreen extends StatefulWidget {
  const LiveBusTrackingScreen({super.key});

  @override
  _LiveBusTrackingScreenState createState() => _LiveBusTrackingScreenState();
}

class _LiveBusTrackingScreenState extends State<LiveBusTrackingScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> activeStudents = [];
  List<Map<String, dynamic>> activeBuses = [];
  bool _hasCenteredOnBus = false;
  String arrivalTime = '--';
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  late AnimationController _animationController;
  late Animation<double> _animation;
  final MapController _mapController = MapController();

  LatLng? get _firstStudentLocation =>
      activeStudents.isNotEmpty
          ? LatLng(
            activeStudents[0]['latitude'],
            activeStudents[0]['longitude'],
          )
          : null;
  LatLng? get _firstBusLocation =>
      activeBuses.isNotEmpty
          ? LatLng(activeBuses[0]['latitude'], activeBuses[0]['longitude'])
          : null;

  @override
  void initState() {
    super.initState();
    _listenToActiveStudents();
    _listenToActiveBuses();
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
    _studentStatusSubscription.cancel();
    _animationController.dispose();
    super.dispose();
  }

  // Listen to all active students in Firebase
  late StreamSubscription<DatabaseEvent> _studentStatusSubscription;

  void _listenToActiveStudents() {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    if (uid == null) return;
    _studentStatusSubscription = _database
        .child('students')
        .child(uid)
        .child('status')
        .onValue
        .listen((event) {
          final status = event.snapshot.value as Map<dynamic, dynamic>?;
          if (status != null &&
              status['isActive'] == true &&
              status['latitude'] != null &&
              status['longitude'] != null) {
            if (mounted) {
              setState(() {
                activeStudents = [
                  {
                    'name': user?.displayName ?? user?.email ?? 'Me',
                    'latitude': (status['latitude'] as num).toDouble(),
                    'longitude': (status['longitude'] as num).toDouble(),
                    'timestamp': status['timestamp'],
                  },
                ];
              });
            }
            arrivalTime = _calculateEta();
          } else {
            setState(() {
              activeStudents = [];
              arrivalTime = _calculateEta();
            });
          }
        });
  }

  // Listen to all active buses in Firebase
  void _listenToActiveBuses() {
    _database.child('buses').onValue.listen((event) {
      final buses = event.snapshot.value as Map<dynamic, dynamic>?;
      if (buses != null) {
        final List<Map<String, dynamic>> active = [];
        buses.forEach((driver, value) {
          final location = value['location'] as Map<dynamic, dynamic>?;
          if (location != null &&
              location['isActive'] == true &&
              location['latitude'] != null &&
              location['longitude'] != null) {
            active.add({
              'driver': driver,
              'latitude': (location['latitude'] as num).toDouble(),
              'longitude': (location['longitude'] as num).toDouble(),
              'timestamp': location['timestamp'],
            });
          }
        });
        setState(() {
          activeBuses = active;
          arrivalTime = _calculateEta();
          if (!_hasCenteredOnBus && _firstBusLocation != null) {
            _mapController.move(_firstBusLocation!, _mapController.zoom);
            _hasCenteredOnBus = true;
          }
        });
        // Update global notifier for ETA
        try {
          Provider.of<EtaNotifier>(context, listen: false).value = arrivalTime;
        } catch (_) {}
      } else {
        setState(() {
          activeBuses = [];
          arrivalTime = _calculateEta();
        });
        // Update global notifier for ETA
        try {
          Provider.of<EtaNotifier>(context, listen: false).value = arrivalTime;
        } catch (_) {}
      }
    });
  }

  // Calculate ETA between bus and student
  // You can change this value to use a different average speed for ETA calculation.
  // For example: 30 km/h = 8.33 m/s, 50 km/h = 13.89 m/s
  static const double _averageSpeedMetersPerSecond = 11.11;

  String _calculateEta() {
    if (_firstStudentLocation != null && _firstBusLocation != null) {
      final Distance distance = Distance();
      final double meters = distance(
        _firstBusLocation!,
        _firstStudentLocation!,
      );
      // Configurable average speed (default 40 km/h = 11.11 m/s)
      double speed = _averageSpeedMetersPerSecond;

      int seconds = (meters / speed).round();
      Duration duration = Duration(seconds: seconds);
      if (duration.inMinutes < 1) {
        return '< 1 min';
      } else {
        return '${duration.inMinutes} min';
      }
    }
    return '--';
  }

  // Prefer bus location for initial map centering
  LatLng _initialMapCenter() {
    if (_firstBusLocation != null) {
      return _firstBusLocation!;
    } else if (_firstStudentLocation != null) {
      return _firstStudentLocation!;
    } else {
      return const LatLng(24.7136, 46.6753); // Default fallback (Riyadh)
    }
  }

  // Automatically fix/center the map on the most relevant point
  void afix() {
    LatLng? center;
    if (_firstStudentLocation != null && _firstBusLocation != null) {
      center = LatLng(
        (_firstStudentLocation!.latitude + _firstBusLocation!.latitude) / 2,
        (_firstStudentLocation!.longitude + _firstBusLocation!.longitude) / 2,
      );
    } else if (_firstStudentLocation != null) {
      center = _firstStudentLocation!;
    } else if (_firstBusLocation != null) {
      center = _firstBusLocation!;
    } else {
      center = const LatLng(24.7136, 46.6753); // Riyadh fallback
    }
    _mapController.move(center, _mapController.zoom);
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
    print(
      "_centerOnStudent called. Location: " + _firstStudentLocation.toString(),
    );
    if (_firstStudentLocation != null) {
      _mapController.move(_firstStudentLocation!, _mapController.zoom);
    } else {
      print("Student location is not available.");
    }
  }

  // Center map on bus location
  void _centerOnBus() {
    if (_firstBusLocation != null) {
      _mapController.move(_firstBusLocation!, _mapController.zoom);
    } else {
      print("Bus location is not available.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(center: _initialMapCenter(), zoom: 14),
            children: [
              TileLayer(
                urlTemplate:
                    'https://api.maptiler.com/maps/basic-v2/{z}/{x}/{y}@2x.png?key=atBiJT3x9AIw2gQtXqfP',
                userAgentPackageName: 'com.example.app',
              ),
              MarkerLayer(
                markers: [
                  // Active student markers
                  ...activeStudents.map(
                    (student) => Marker(
                      point: LatLng(student['latitude'], student['longitude']),
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
                  ),
                  // Active bus markers
                  ...activeBuses.map(
                    (bus) => Marker(
                      point: LatLng(bus['latitude'], bus['longitude']),
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
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 40,
            left: 20,
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
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
                padding: const EdgeInsets.all(10),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.black,
                  size: 24,
                ),
              ),
            ),
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
            Text(
              'Bus Arrival Time',
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              arrivalTime,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
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
