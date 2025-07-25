import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_bus_tracking_app/eta_notifier.dart';
import 'package:school_bus_tracking_app/screens/bus_details_screen.dart';
import 'package:school_bus_tracking_app/screens/live_bus_tracking_screen.dart';
import 'package:school_bus_tracking_app/screens/profile_screen.dart';
import 'package:school_bus_tracking_app/screens/support_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentHomeScreen extends StatefulWidget {
  final String studentName;

  const StudentHomeScreen({super.key, required this.studentName});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  bool isActive = false;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  String? _fullName;
  bool _loadingName = true;

  // Store driver data
  Map<String, dynamic>? _driverData;
  bool _loadingDriver = true;
  String? _driverName;
  String? _driverId;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _initializeFirebase();
  }

  // Fetch user data including fullName and driverId
  Future<void> _fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Fetch student name
        final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
        if (userDoc.exists && userDoc.data() != null) {
          if (!mounted) return;
          setState(() {
            _fullName = userDoc.data()!['fullName'] ?? widget.studentName;
            _loadingName = false;
          });
        } else {
          if (!mounted) return;
          setState(() {
            _fullName = widget.studentName;
            _loadingName = false;
          });
        }

        // Try to fetch driverId from Firestore student_driver_assignments
        final assignmentDoc =
            await FirebaseFirestore.instance
                .collection('student_driver_assignments')
                .doc(user.uid)
                .get();
        if (assignmentDoc.exists && assignmentDoc.data() != null) {
          final driverId = assignmentDoc.data()!['driverId'];
          if (driverId != null) {
            if (!mounted) return;
            setState(() {
              _driverId = driverId;
            });
            await _fetchDriverName(driverId);
            await _fetchDriverData(driverId);
            return;
          }
        }

        // Fallback: Check Realtime Database for student_driver_assignments
        final assignmentSnapshot =
            await _database
                .child('student_driver_assignments')
                .child(user.uid)
                .get();
        if (assignmentSnapshot.exists && assignmentSnapshot.value != null) {
          final data = Map<String, dynamic>.from(
            assignmentSnapshot.value as Map,
          );
          final driverId = data['driverId'];
          if (driverId != null) {
            if (!mounted) return;
            setState(() {
              _driverId = driverId;
            });
            await _fetchDriverName(driverId);
            await _fetchDriverData(driverId);
            return;
          }
        }

        // Final fallback: Fetch first active driver from buses
        await _fetchFallbackDriver();
      } else {
        if (!mounted) return;
        setState(() {
          _fullName = widget.studentName;
          _loadingName = false;
          _driverData = null;
          _loadingDriver = false;
          _driverName = 'No Driver Assigned';
        });
      }
    } catch (e) {
      print('Error fetching user data: $e');
      if (!mounted) return;
      setState(() {
        _fullName = widget.studentName;
        _loadingName = false;
        _driverData = null;
        _loadingDriver = false;
        _driverName = 'No Driver Assigned';
      });
    }
  }

  // Fallback: Fetch first active driver from buses
  Future<void> _fetchFallbackDriver() async {
    try {
      final busesSnapshot = await _database.child('buses').get();
      if (busesSnapshot.exists && busesSnapshot.value != null) {
        final buses = Map<String, dynamic>.from(busesSnapshot.value as Map);
        // Find first active driver
        for (var entry in buses.entries) {
          final driverId = entry.key;
          final locationData = Map<String, dynamic>.from(
            entry.value['location'],
          );
          if (locationData['isActive'] == true) {
            if (!mounted) return;
            setState(() {
              _driverId = driverId;
            });
            await _fetchDriverName(driverId);
            await _fetchDriverData(driverId);
            return;
          }
        }
        // No active driver found
        if (!mounted) return;
        setState(() {
          _driverData = null;
          _loadingDriver = false;
          _driverName = 'No Active Driver Found';
        });
      } else {
        if (!mounted) return;
        setState(() {
          _driverData = null;
          _loadingDriver = false;
          _driverName = 'No Active Driver Found';
        });
      }
    } catch (e) {
      print('Error fetching fallback driver: $e');
      if (!mounted) return;
      setState(() {
        _driverData = null;
        _loadingDriver = false;
        _driverName = 'No Active Driver Found';
      });
    }
  }

  // Fetch driver name from Firestore using driverId
  Future<void> _fetchDriverName(String driverId) async {
    try {
      final driverDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(driverId)
              .get();
      if (driverDoc.exists && driverDoc.data() != null) {
        if (!mounted) return;
        setState(() {
          _driverName = driverDoc.data()!['fullName'] ?? 'Unknown Driver';
        });
      } else {
        if (!mounted) return;
        setState(() {
          _driverName = 'Unknown Driver';
        });
      }
    } catch (e) {
      print('Error fetching driver name: $e');
      if (!mounted) return;
      setState(() {
        _driverName = 'Unknown Driver';
      });
    }
  }

  // Fetch driver data from Firebase Realtime Database
  Future<void> _fetchDriverData(String driverId) async {
    setState(() {
      _loadingDriver = true;
    });
    try {
      final snapshot =
          await _database
              .child('buses')
              .child(driverId)
              .child('location')
              .get();
      if (snapshot.exists && snapshot.value != null) {
        final driverData = Map<String, dynamic>.from(snapshot.value as Map);
        if (!mounted) return;
        setState(() {
          _driverData = driverData;
          _loadingDriver = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _driverData = null;
          _loadingDriver = false;
        });
      }
    } catch (e) {
      print('Error fetching driver data: $e');
      if (!mounted) return;
      setState(() {
        _driverData = null;
        _loadingDriver = false;
      });
    }
  }

  // Initialize Firebase and check initial status
  void _initializeFirebase() async {
    try {
      if (_uid == null) return;
      // Fetch initial status from Firebase
      final snapshot =
          await _database.child('students').child(_uid!).child('status').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        if (!mounted) return;
        setState(() {
          isActive = data['isActive'] ?? false;
        });
      }
    } catch (e) {
      print('Error initializing Firebase: $e');
    }
  }

  // Driver Info Card
  Widget _buildDriverInfoCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            offset: const Offset(0, 4),
            blurRadius: 14,
          ),
        ],
        border: Border.all(
          color: const Color(0xFF5A8DEE).withOpacity(0.14),
          width: 1.2,
        ),
      ),
      child:
          _loadingDriver
              ? const Center(child: CircularProgressIndicator())
              : _driverData == null
              ? Row(
                children: [
                  Icon(Icons.directions_bus, color: Colors.grey[400], size: 32),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Text(
                      _driverName ?? 'Driver data unavailable.',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                ],
              )
              : Row(
                children: [
                  Icon(
                    _driverData!['isActive'] == true
                        ? Icons.directions_bus_filled
                        : Icons.directions_bus,
                    color:
                        _driverData!['isActive'] == true
                            ? Colors.green
                            : Colors.grey,
                    size: 32,
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _driverName ?? 'Driver Location',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Color(0xFF5A8DEE),
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Lat: ${_driverData!['latitude']?.toStringAsFixed(5) ?? '-'}, '
                              'Lng: ${_driverData!['longitude']?.toStringAsFixed(5) ?? '-'}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              color: Colors.amber[700],
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _driverData!['timestamp'] != null
                                  ? DateTime.fromMillisecondsSinceEpoch(
                                    _driverData!['timestamp'],
                                  ).toLocal().toString()
                                  : '-',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.circle,
                              size: 12,
                              color:
                                  _driverData!['isActive'] == true
                                      ? Colors.green
                                      : Colors.red,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _driverData!['isActive'] == true
                                  ? 'Active'
                                  : 'Inactive',
                              style: TextStyle(
                                fontSize: 13,
                                color:
                                    _driverData!['isActive'] == true
                                        ? Colors.green
                                        : Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }

  // Handle location permission and update Firebase
  Future<void> _handleLocationAndFirebaseUpdate(bool newValue) async {
    if (newValue) {
      // Request location permission when toggling to active
      final status = await _requestLocationPermission();
      if (status == PermissionStatus.granted) {
        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          await _updateFirebaseStatus(
            isActive: newValue,
            latitude: position.latitude,
            longitude: position.longitude,
          );
        } catch (e) {
          print('Error getting location: $e');
          // Revert toggle if location fetch fails
          setState(() {
            isActive = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to get location. Please try again.'),
            ),
          );
        }
      } else {
        // Revert toggle if permission is denied
        setState(() {
          isActive = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied.')),
        );
      }
    } else {
      // Update Firebase when toggling to inactive
      await _updateFirebaseStatus(isActive: newValue);
    }
  }

  // Request location permission
  Future<PermissionStatus> _requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are disabled
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enable location services.')),
      );
      return PermissionStatus.denied;
    }

    PermissionStatus permission = await Permission.location.status;
    if (permission.isDenied) {
      permission = await Permission.location.request();
    }

    return permission;
  }

  // Update Firebase Realtime Database with status and location
  Future<void> _updateFirebaseStatus({
    required bool isActive,
    double? latitude,
    double? longitude,
  }) async {
    try {
      if (_uid == null) return;
      await _database.child('students').child(_uid!).child('status').set({
        'isActive': isActive,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': ServerValue.timestamp,
      });
    } catch (e) {
      print('Error updating Firebase: $e');
      throw e;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _buildWelcomeSection(context),
                  const SizedBox(height: 24),
                  _buildDriverInfoCard(context),
                  const SizedBox(height: 24),
                  _buildBusStatusCard(context),
                  const SizedBox(height: 32),
                  _buildQuickActionsGrid(context),
                  const SizedBox(height: 32),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  Widget _buildWelcomeSection(BuildContext context) {
    final eta = Provider.of<EtaNotifier>(context, listen: false).value;

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        border: Border.all(
          color: const Color(0xFF5A8DEE).withOpacity(0.15),
          width: 1.2,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            offset: const Offset(0, 6),
            blurRadius: 18,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.waving_hand,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF374151),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _loadingName
                        ? SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : Text(
                          _fullName ?? '',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                  ],
                ),
              ),
              // Modern toggle button
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      isActive
                          ? const Color(0xFF10B981).withOpacity(0.15)
                          : Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        isActive ? const Color(0xFF10B981) : Colors.grey[400]!,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isActive
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color:
                          isActive ? const Color(0xFF10B981) : Colors.grey[500],
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          isActive = !isActive;
                          _handleLocationAndFirebaseUpdate(isActive);
                        });
                      },
                      child: Text(
                        isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          color:
                              isActive
                                  ? const Color(0xFF10B981)
                                  : Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Switch(
                      value: isActive,
                      onChanged: (val) {
                        setState(() {
                          isActive = val;
                          _handleLocationAndFirebaseUpdate(val);
                        });
                      },
                      activeColor: const Color(0xFF10B981),
                      inactiveThumbColor: Colors.grey[400],
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF10B981).withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.access_time,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Bus ETA: $eta',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusStatusCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5A8DEE), Color(0xFF764BA2)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.15),
            offset: const Offset(0, 4),
            blurRadius: 18,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.directions_bus_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Live Bus Status',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.7,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LiveBusTrackingScreen(),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.map_outlined,
                  size: 18,
                  color: Color(0xFF667EEA),
                ),
                label: const Text(
                  'View on Map',
                  style: TextStyle(
                    color: Color(0xFF667EEA),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.1,
          children: [
            _buildActionCard(
              context,
              icon: Icons.my_location_rounded,
              title: 'Track Bus',
              subtitle: 'Live location',
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LiveBusTrackingScreen(),
                  ),
                );
              },
            ),
            _buildActionCard(
              context,
              icon: Icons.info_outline_rounded,
              title: 'Bus Details',
              subtitle: 'View info',
              gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => BusDetailsScreen()),
                );
              },
            ),
            _buildActionCard(
              context,
              icon: Icons.support_agent_rounded,
              title: 'Support',
              subtitle: 'Get help',
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SupportScreen()),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 4),
            blurRadius: 16,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 28, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            offset: const Offset(0, -4),
            blurRadius: 16,
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                context,
                icon: Icons.home_rounded,
                label: 'Home',
                isActive: true,
                onTap: () {
                  // Already on home
                },
              ),
              _buildNavItem(
                context,
                icon: Icons.map_rounded,
                label: 'Tracking',
                isActive: false,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LiveBusTrackingScreen(),
                    ),
                  );
                },
              ),
              _buildNavItem(
                context,
                icon: Icons.person_rounded,
                label: 'Profile',
                isActive: false,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ProfileScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color:
              isActive
                  ? const Color(0xFF667EEA).withOpacity(0.1)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFF667EEA) : Colors.grey[500],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? const Color(0xFF667EEA) : Colors.grey[500],
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
