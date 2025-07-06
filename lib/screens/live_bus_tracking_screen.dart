// lib/screens/live_bus_tracking_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:school_bus_tracking_app/screens/bus_details_screen.dart';

class LiveBusTrackingScreen extends StatefulWidget {
  @override
  _LiveBusTrackingScreenState createState() => _LiveBusTrackingScreenState();
}

class _LiveBusTrackingScreenState extends State<LiveBusTrackingScreen> {
  LatLng studentLocation = LatLng(24.7136, 46.6753);
  LatLng busLocation = LatLng(24.7236, 46.6853);
  String arrivalTime = '10 min';

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Live Bus Tracking')),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(center: studentLocation, zoom: 14),
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
                    child: Icon(
                      Icons.person_pin_circle,
                      color: Colors.blue,
                      size: 40,
                    ),
                  ),
                  Marker(
                    point: busLocation,
                    width: 40,
                    height: 40,
                    child: Icon(
                      Icons.directions_bus,
                      color: Colors.red,
                      size: 40,
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
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.directions_bus),
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
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              arrivalTime,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            LinearProgressIndicator(
              value: 0.3, // Replace with actual progress
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          ],
        ),
      ),
    );
  }
}
