import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/attendance_service.dart';
import 'staff_detail_screen.dart';
import '../utils/smooth_transitions.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<dynamic> _allStaff = [];
  List<dynamic> _todayAttendance = [];
  bool _isLoading = true;
  StreamSubscription? _attendanceSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupRealtime();
  }

  @override
  void dispose() {
    _attendanceSubscription?.cancel();
    super.dispose();
  }

  void _setupRealtime() {
    final service = Provider.of<AttendanceService>(context, listen: false);
    _attendanceSubscription = service.attendanceStream.listen((data) {
      if (mounted) {
        debugPrint('REALTIME: Received ${data.length} records');
        setState(() {
          // Update online status from stream, ignoring old forgotten sessions (>24 hours)
          _todayAttendance = data.where((record) {
            if (record['check_out'] != null) return false;
            final checkInStr = record['check_in'];
            if (checkInStr == null) return false;
            try {
              final checkInTime = DateTime.parse(checkInStr);
              final diff = DateTime.now().difference(checkInTime);
              return diff.inHours < 24;
            } catch (e) {
              return false;
            }
          }).toList();
          debugPrint('REALTIME: Active sessions: ${_todayAttendance.length}');
        });
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final service = Provider.of<AttendanceService>(context, listen: false);
    
    final staff = await service.getAllStaff();
    final allHistory = await service.getAllAttendanceHistory();
    
    debugPrint('All History Count: ${allHistory.length}');
    for (var rec in allHistory) {
      debugPrint('Record: User: ${rec['user_id']}, CheckOut: ${rec['check_out']}');
    }

    // Simple logic: If check_out is null and check_in is within the last 24 hours, the person is active/online.
    final today = allHistory.where((record) {
      if (record['check_out'] != null) return false;
      final checkInStr = record['check_in'];
      if (checkInStr == null) return false;
      try {
        final checkInTime = DateTime.parse(checkInStr);
        final diff = DateTime.now().difference(checkInTime);
        return diff.inHours < 24;
      } catch (e) {
        return false;
      }
    }).toList();
    
    debugPrint('Filtering found ${today.length} active sessions');

    setState(() {
      _allStaff = staff;
      _todayAttendance = today;
      _isLoading = false;
    });
  }

  Future<void> _exportLogsToCSV() async {
    setState(() => _isLoading = true);
    try {
      final service = Provider.of<AttendanceService>(context, listen: false);
      final staff = await service.getAllStaff();
      final allHistory = await service.getAllAttendanceHistory();

      // Create a map of staff ID to full name for quick lookup
      final Map<String, String> staffMap = {
        for (var s in staff) s['id'].toString(): s['full_name'].toString()
      };

      final nowTime = DateTime.now();
      final currentYear = nowTime.year;
      final currentMonth = nowTime.month;

      // Filter all logs to ONLY include the current month to prevent flooding
      final currentMonthHistory = allHistory.where((record) {
        if (record['check_in'] == null) return false;
        try {
          final checkInLocal = DateTime.parse(record['check_in']).toLocal();
          return checkInLocal.year == currentYear && checkInLocal.month == currentMonth;
        } catch (e) {
          return false;
        }
      }).toList();

      // Track working days and hours per employee for the current month
      final Map<String, Set<String>> monthlyActiveDays = {};
      final Map<String, double> monthlyHours = {};

      // Initialize maps for all staff
      for (var s in staff) {
        final id = s['id'].toString();
        monthlyActiveDays[id] = {};
        monthlyHours[id] = 0.0;
      }

      for (var record in currentMonthHistory) {
        final userId = record['user_id']?.toString() ?? '';
        if (!monthlyActiveDays.containsKey(userId)) continue;

        final checkInLocal = DateTime.parse(record['check_in']).toLocal();
        final dayStr = '${checkInLocal.year}-${checkInLocal.month.toString().padLeft(2, '0')}-${checkInLocal.day.toString().padLeft(2, '0')}';
        monthlyActiveDays[userId]!.add(dayStr);

        // Calculate hours
        final start = DateTime.parse(record['check_in']).toUtc();
        final end = record['check_out'] != null
            ? DateTime.parse(record['check_out']).toUtc()
            : DateTime.now().toUtc();
        final diff = end.difference(start).inSeconds;
        final recordHours = (diff < 0 ? 0 : diff) / 3600.0;
        monthlyHours[userId] = (monthlyHours[userId] ?? 0.0) + recordHours;
      }

      // Helper to escape CSV values
      String escapeCSV(String? val) {
        if (val == null) return '';
        String escaped = val.replaceAll('"', '""');
        if (escaped.contains(',') || escaped.contains('\n') || escaped.contains('"')) {
          return '"$escaped"';
        }
        return escaped;
      }

      final csvBuffer = StringBuffer();
      
      // --- Section 1: Monthly Summary ---
      final monthName = DateFormat('MMMM yyyy').format(nowTime);
      csvBuffer.writeln('MONTHLY ATTENDANCE SUMMARY ($monthName)');
      csvBuffer.writeln('Employee Name,Employee ID,Working Days (Current Month),Total Hours (Current Month)');
      
      for (var s in staff) {
        final id = s['id'].toString();
        final name = s['full_name']?.toString() ?? 'Unknown';
        final days = monthlyActiveDays[id]?.length ?? 0;
        final hours = monthlyHours[id] ?? 0.0;
        csvBuffer.writeln([
          escapeCSV(name),
          escapeCSV(id),
          escapeCSV(days.toString()),
          escapeCSV(hours.toStringAsFixed(2)),
        ].join(','));
      }

      csvBuffer.writeln(); // Empty separating line
      csvBuffer.writeln(); // Empty separating line

      // --- Section 2: Detailed Attendance Logs ---
      csvBuffer.writeln('DETAILED ATTENDANCE LOGS ($monthName)');
      csvBuffer.writeln('Record ID,Employee Name,Employee ID,Check In,Check Out,Duration (Hours),Status');

      for (var record in currentMonthHistory) {
        final id = record['id']?.toString() ?? '';
        final userId = record['user_id']?.toString() ?? '';
        final employeeName = staffMap[userId] ?? 'Unknown Employee';
        
        final checkInStr = record['check_in'] != null 
            ? DateTime.parse(record['check_in']).toLocal().toString() 
            : '';
        final checkOutStr = record['check_out'] != null 
            ? DateTime.parse(record['check_out']).toLocal().toString() 
            : 'LIVE';

        // Calculate hours
        double hours = 0.0;
        if (record['check_in'] != null) {
          final start = DateTime.parse(record['check_in']).toUtc();
          final end = record['check_out'] != null
              ? DateTime.parse(record['check_out']).toUtc()
              : DateTime.now().toUtc();
          final diff = end.difference(start).inSeconds;
          hours = (diff < 0 ? 0 : diff) / 3600.0;
        }
        
        final status = record['check_out'] != null ? 'Completed' : 'Active';

        csvBuffer.writeln([
          escapeCSV(id),
          escapeCSV(employeeName),
          escapeCSV(userId),
          escapeCSV(checkInStr),
          escapeCSV(checkOutStr),
          escapeCSV(hours.toStringAsFixed(2)),
          escapeCSV(status),
        ].join(','));
      }

      final csvContent = csvBuffer.toString();
      final fileName = 'attendance_export_${nowTime.year}_${nowTime.month.toString().padLeft(2, '0')}.csv';

      if (kIsWeb) {
        final bytes = const Utf8Encoder().convert(csvContent);
        final file = XFile.fromData(
          bytes,
          mimeType: 'text/csv',
          name: fileName,
        );
        final params = ShareParams(
          files: [file],
          subject: 'Attendance Export',
        );
        await SharePlus.instance.share(params);
      } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        final downloadsDir = await getDownloadsDirectory();
        if (downloadsDir != null) {
          final file = File('${downloadsDir.path}/$fileName');
          await file.writeAsString(csvContent);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('File downloaded to: ${file.path}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                backgroundColor: Colors.black,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                margin: const EdgeInsets.all(24),
              ),
            );
          }
        } else {
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/$fileName');
          await file.writeAsString(csvContent);
          final params = ShareParams(
            files: [XFile(file.path, mimeType: 'text/csv')],
            subject: 'Attendance Export',
          );
          await SharePlus.instance.share(params);
        }
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsString(csvContent);
        final params = ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          subject: 'Attendance Export',
        );
        await SharePlus.instance.share(params);
      }
    } catch (e) {
      debugPrint('Export CSV Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export CSV: $e', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.all(24),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Admin Console'),
        actions: [
          IconButton(
            onPressed: _exportLogsToCSV,
            icon: const Icon(Icons.file_download_outlined, size: 24),
            tooltip: 'Export CSV',
          ),
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded, size: 24),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: Colors.black,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsRow(),
                    const SizedBox(height: 48),
                    const Text(
                      'Staff Roster',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black26, letterSpacing: 2),
                    ),
                    const SizedBox(height: 24),
                    _buildStaffList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
        children: [
          _buildStatCard('Headcount', _allStaff.length.toString(), Icons.people_alt_rounded),
          const SizedBox(width: 16),
          _buildStatCard('Online Now', _todayAttendance.map((e) => e['user_id']).toSet().length.toString(), Icons.radar_rounded, isAccent: true),
        ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, {bool isAccent = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isAccent ? Colors.black : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(32),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: isAccent ? Colors.white : Colors.black, size: 20),
            const SizedBox(height: 20),
            Text(
              value,
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: isAccent ? Colors.white : Colors.black),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: isAccent ? Colors.white38 : Colors.black26, letterSpacing: 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _allStaff.length,
      itemBuilder: (context, index) {
        final staff = _allStaff[index];
        final bool isOnline = _todayAttendance.any((a) => a['user_id'] == staff['id']);
        if (isOnline) debugPrint('Staff ${staff['full_name']} is online');
        

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.black.withValues(alpha: 0.03)),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: isOnline ? Colors.black : Colors.black.withValues(alpha: 0.05),
              child: Text(
                (staff['full_name'] ?? '?')[0].toUpperCase(),
                style: TextStyle(color: isOnline ? Colors.white : Colors.black26, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              staff['full_name'] ?? 'Employee',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              isOnline ? 'Active Now' : 'Offline',
              style: TextStyle(color: isOnline ? Colors.black : Colors.black26, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.black26),
            onTap: () => Navigator.push(
              context,
              SmoothPageRoute(child: StaffDetailScreen(staff: staff)),
            ),
          ),
        );
      },
    );
  }
}
