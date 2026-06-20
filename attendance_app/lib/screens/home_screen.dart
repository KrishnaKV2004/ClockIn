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

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _todayAttendance;
  String? _fullName;
  Position? _currentPosition;
  double _distanceToOffice = 0;
  bool _isLoading = true;
  bool _isMarkingAttendance = false;
  Timer? _timer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _loadInitialData();
    _startLocationTracking();
    LocationService.getCurrentLocation().catchError((e) => debugPrint('Initial location request error: $e'));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
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
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      ).catchError((e) => throw 'Location access failed. Ensure GPS is on.');

      final isInside = LocationService.isWithinRadius(pos);

      if (!isInside) {
        if (mounted) {
          _showError('OFFICE RADIUS EXCEEDED', 'You are ${_distanceToOffice.toStringAsFixed(0)}m away. Move closer to the office.');
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
       if (mounted) _showError('ACCESS DENIED', e.toString());
    } finally {
      if (mounted) setState(() => _isMarkingAttendance = false);
    }
  }

  void _showError(String title, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 12, letterSpacing: 1)),
            Text(message, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.all(24),
      ),
    );
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
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
            icon: const Icon(Icons.analytics_outlined, size: 22),
          ),
        ),
        title: const Text('MOON ARC', style: TextStyle(letterSpacing: 4, fontSize: 14, fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              _loadInitialData();
            },
            icon: const Icon(Icons.tune_rounded, size: 22),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : Column(
              children: [
                const SizedBox(height: 40),
                _buildProfileHeader(),
                const Spacer(),
                _buildFingerprintButton(isCheckedIn),
                const Spacer(),
                _buildStatusCards(),
                const SizedBox(height: 60),
              ],
            ),
    );
  }

  Widget _buildProfileHeader() {
    String firstName = _fullName?.split(' ')[0] ?? 'Explorer';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Text(
            'HELLO, ${firstName.toUpperCase()}',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.black38),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ready for Duty?',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: -1),
          ),
        ],
      ),
    );
  }

  Widget _buildFingerprintButton(bool isCheckedIn) {
    return GestureDetector(
      onTap: _handleAttendance,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulse Animation
          if (!isCheckedIn && !_isMarkingAttendance)
            ScaleTransition(
              scale: Tween(begin: 1.0, end: 1.4).animate(_pulseController),
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.03),
                ),
              ),
            ),
          
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: isCheckedIn ? const Color(0xFFF1F5F9) : Colors.black,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: isCheckedIn ? Colors.black.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.2),
                  blurRadius: 50,
                  spreadRadius: 5,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: _isMarkingAttendance
                ? const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.fingerprint_rounded,
                        size: 80,
                        color: isCheckedIn ? Colors.black12 : Colors.white,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isCheckedIn ? 'ACTIVE' : 'START',
                        style: TextStyle(
                          color: isCheckedIn ? Colors.black26 : Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCards() {
    String checkInTime = _todayAttendance != null 
        ? DateFormat('hh:mm a').format(DateTime.parse(_todayAttendance!['check_in']))
        : '--:--';
        
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildInfoItem('LAST IN', checkInTime),
          Container(width: 1, height: 30, color: Colors.black12),
          _buildInfoItem('PROXIMITY', '${_distanceToOffice.toStringAsFixed(0)}M'),
          Container(width: 1, height: 30, color: Colors.black12),
          _buildInfoItem('STATUS', _todayAttendance == null ? 'OFF' : 'LIVE'),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black26, letterSpacing: 1)),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
      ],
    );
  }
}
