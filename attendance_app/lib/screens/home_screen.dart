import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/attendance_service.dart';
import '../services/profile_service.dart';
import '../services/location_service.dart';
import '../services/supabase_service.dart';
import 'login_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _todayAttendance;
  String? _fullName;
  Position? _currentPosition;
  double _distanceToOffice = 0;
  bool _isLoading = true;
  bool _isMarkingAttendance = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final attendanceService = Provider.of<AttendanceService>(context, listen: false);
      final profileService = Provider.of<ProfileService>(context, listen: false);
      
      final data = await attendanceService.getTodayAttendance();
      final profile = await profileService.getProfile();

      if (mounted) {
        setState(() {
          _todayAttendance = data;
          _fullName = profile?['full_name'];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading initial data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Database Error: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: const StadiumBorder(),
            margin: const EdgeInsets.only(bottom: 10, left: 32, right: 32),
          ),
        );
      }
    }
  }

  void _startLocationTracking() {
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        final pos = await LocationService.getCurrentLocation();
        if (mounted) {
          setState(() {
            _currentPosition = pos;
            _distanceToOffice = LocationService.getDistanceFromOffice(pos);
          });
        }
      } catch (e) {
        debugPrint('Location Error: $e');
      }
    });
  }

  Future<void> _handleAttendance() async {
    if (_isMarkingAttendance) return;

    setState(() => _isMarkingAttendance = true);

    try {
      // Use shorter timeout for the check-in button to avoid long hangs
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      ).catchError((e) => throw 'Could not get location. Try again. ($e)');

      final isInside = LocationService.isWithinRadius(pos);

      if (!isInside) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You are outside the office radius!'),
              backgroundColor: Colors.orangeAccent,
              behavior: SnackBarBehavior.floating,
              shape: StadiumBorder(),
              margin: EdgeInsets.only(bottom: 10, left: 32, right: 32),
            ),
          );
        }
        return;
      }

      final attendanceService = Provider.of<AttendanceService>(context, listen: false);
      if (_todayAttendance == null || _todayAttendance!['check_out'] != null) {
        await attendanceService.checkIn(pos.latitude, pos.longitude);
      } else {
        await attendanceService.checkOut();
      }

      await _loadInitialData();
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: const StadiumBorder(),
            margin: const EdgeInsets.only(bottom: 10, left: 32, right: 32),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isMarkingAttendance = false);
    }
  }

  Future<void> _logout() async {
    await SupabaseService.client.auth.signOut();
    if (mounted) {
       Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isCheckedIn = _todayAttendance != null && _todayAttendance!['check_out'] == null;
    String statusText = isCheckedIn ? 'Checked In' : 'Ready to Check In';
    Color statusColor = isCheckedIn ? Colors.greenAccent : const Color(0xFF6366F1);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              );
            },
            icon: const Icon(Icons.history),
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.redAccent),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildStatusCard(statusText, statusColor),
                  const SizedBox(height: 48),
                  Center(
                    child: _buildAttendanceButton(isCheckedIn),
                  ),
                  const SizedBox(height: 48),
                  _buildLocationInfo(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    final user = SupabaseService.client.auth.currentUser;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hello,',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 18),
        ),
        Text(
          _fullName ?? user?.email?.split('@').first.toUpperCase() ?? 'Employee',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildStatusCard(String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.timer_outlined, color: color),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Today\'s Status',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
              ),
              Text(
                text,
                style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceButton(bool isCheckedIn) {
    return GestureDetector(
      onTap: _handleAttendance,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isCheckedIn ? Colors.redAccent.withValues(alpha: 0.1) : const Color(0xFF6366F1).withValues(alpha: 0.1),
          border: Border.all(
            color: isCheckedIn ? Colors.redAccent : const Color(0xFF6366F1),
            width: 4,
          ),
          boxShadow: [
            BoxShadow(
              color: (isCheckedIn ? Colors.redAccent : const Color(0xFF6366F1)).withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: _isMarkingAttendance
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isCheckedIn ? Icons.exit_to_app : Icons.touch_app,
                    size: 64,
                    color: isCheckedIn ? Colors.redAccent : const Color(0xFF6366F1),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isCheckedIn ? 'CHECK OUT' : 'CHECK IN',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isCheckedIn ? Colors.redAccent : const Color(0xFF6366F1),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildLocationInfo() {
    bool isNearby = _distanceToOffice <= LocationService.officeRadiusInMeters;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Icon(
            isNearby ? Icons.location_on : Icons.location_off,
            color: isNearby ? Colors.greenAccent : Colors.orangeAccent,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isNearby ? 'You are within range' : 'You are out of range',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_distanceToOffice.toStringAsFixed(1)} meters from office',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
