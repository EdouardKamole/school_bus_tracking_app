import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:school_bus_tracking_app/screens/live_bus_tracking_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class BusDetailsScreen extends StatefulWidget {
  const BusDetailsScreen({super.key});

  @override
  State<BusDetailsScreen> createState() => _BusDetailsScreenState();
}

class _BusDetailsScreenState extends State<BusDetailsScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  // Driver and bus data
  String? _driverName;
  String? _phoneNumber;
  String? _busPhotoUrl;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchBusDetails();
  }

  // Fetch bus details including driverId, driver name, phone number, and bus photo
  Future<void> _fetchBusDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_uid == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'User not logged in';
        });
        return;
      }

      // Try to fetch driverId from Firestore student_driver_assignments
      String? driverId;
      final assignmentDoc =
          await FirebaseFirestore.instance
              .collection('student_driver_assignments')
              .doc(_uid)
              .get();
      if (assignmentDoc.exists && assignmentDoc.data() != null) {
        driverId = assignmentDoc.data()!['driverId'];
      }

      // Fallback: Check Realtime Database for student_driver_assignments
      if (driverId == null) {
        final assignmentSnapshot =
            await _database
                .child('student_driver_assignments')
                .child(_uid!)
                .get();
        if (assignmentSnapshot.exists && assignmentSnapshot.value != null) {
          final data = Map<String, dynamic>.from(
            assignmentSnapshot.value as Map,
          );
          driverId = data['driverId'];
        }
      }

      // Final fallback: Fetch first active driver from buses
      if (driverId == null) {
        final busesSnapshot = await _database.child('buses').get();
        if (busesSnapshot.exists && busesSnapshot.value != null) {
          final buses = Map<String, dynamic>.from(busesSnapshot.value as Map);
          for (var entry in buses.entries) {
            final locationData = Map<String, dynamic>.from(
              entry.value['location'],
            );
            if (locationData['isActive'] == true) {
              driverId = entry.key;
              break;
            }
          }
        }
      }

      if (driverId != null) {
        // Fetch driver details from Firestore
        final driverDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(driverId)
                .get();
        String driverName = 'Unknown Driver';
        String phoneNumber = 'N/A';
        if (driverDoc.exists && driverDoc.data() != null) {
          driverName = driverDoc.data()!['fullName'] ?? 'Unknown Driver';
          phoneNumber = driverDoc.data()!['phone'] ?? 'N/A';
        }

        // Fetch bus details from Realtime Database
        final busSnapshot =
            await _database.child('buses').child(driverId).get();
        if (busSnapshot.exists && busSnapshot.value != null) {
          final busData = Map<String, dynamic>.from(busSnapshot.value as Map);
          if (!mounted) return;
          setState(() {
            _driverName = driverName;
            _phoneNumber = phoneNumber;
            _busPhotoUrl = busData['busPhotoUrl'] ?? null;
            _isLoading = false;
          });
        } else {
          if (!mounted) return;
          setState(() {
            _driverName = driverName;
            _phoneNumber = phoneNumber;
            _busPhotoUrl = null;
            _isLoading = false;
            _errorMessage = 'Bus details unavailable';
          });
        }
      } else {
        if (!mounted) return;
        setState(() {
          _driverName = 'No Driver Assigned';
          _phoneNumber = 'N/A';
          _busPhotoUrl = null;
          _isLoading = false;
          _errorMessage = 'No active driver found';
        });
      }
    } catch (e) {
      print('Error fetching bus details: $e');
      if (!mounted) return;
      setState(() {
        _driverName = 'No Driver Assigned';
        _phoneNumber = 'N/A';
        _busPhotoUrl = null;
        _isLoading = false;
        _errorMessage = 'Failed to load bus details';
      });
    }
  }

  // Launch dialer with phone number
  Future<void> _launchDialer(String phoneNumber) async {
    try {
      final Uri phoneUri = Uri.parse('tel:$phoneNumber');
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Unable to open dialer')));
      }
    } catch (e) {
      print('Error launching dialer: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to open dialer')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Bus Details',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Bus Image
                    Container(
                      height: 220,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.grey[200],
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            offset: const Offset(0, 4),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child:
                            _busPhotoUrl != null
                                ? Image.network(
                                  _busPhotoUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (context, error, stackTrace) =>
                                          _buildImagePlaceholder(),
                                )
                                : _buildImagePlaceholder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Error Message (if any)
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.red[600],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    // Driver Card
                    _buildDetailCard(
                      icon: Icons.person_rounded,
                      title: 'Driver',
                      value: _driverName ?? 'N/A',
                      isPhone: false,
                    ),
                    const SizedBox(height: 16),
                    // Phone Card
                    _buildDetailCard(
                      icon: Icons.phone_rounded,
                      title: 'Phone',
                      value: _phoneNumber ?? 'N/A',
                      isPhone: true,
                      onTap:
                          _phoneNumber != null && _phoneNumber != 'N/A'
                              ? () => _launchDialer(_phoneNumber!)
                              : null,
                    ),
                    const SizedBox(height: 32),
                    // View on Map Button
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LiveBusTrackingScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF667EEA),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        shadowColor: Colors.black.withOpacity(0.1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.map_outlined, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'View on Map',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  // Placeholder for bus image
  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Icon(Icons.directions_bus_rounded, size: 80, color: Colors.grey),
      ),
    );
  }

  // Detail card widget
  Widget _buildDetailCard({
    required IconData icon,
    required String title,
    required String value,
    required bool isPhone,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF5A8DEE).withOpacity(0.15),
            width: 1.2,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 24, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          value,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color:
                                isPhone && onTap != null
                                    ? const Color(0xFF667EEA)
                                    : const Color(0xFF1F2937),
                            decoration:
                                isPhone && onTap != null
                                    ? TextDecoration.underline
                                    : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isPhone && onTap != null)
                    const Icon(Icons.call, color: Color(0xFF667EEA), size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
