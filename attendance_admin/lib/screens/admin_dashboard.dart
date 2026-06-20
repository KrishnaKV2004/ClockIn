import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/attendance_service.dart';
import 'staff_detail_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<dynamic> _allStaff = [];
  List<dynamic> _todayAttendance = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final service = Provider.of<AttendanceService>(context, listen: false);
    
    final staff = await service.getAllStaff();
    final allHistory = await service.getAllAttendanceHistory();
    
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    
    final today = allHistory.where((record) {
      final checkIn = record['check_in'] as String;
      return checkIn.startsWith(todayStr) && record['check_out'] == null;
    }).toList();

    setState(() {
      _allStaff = staff;
      _todayAttendance = today;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Admin Console'),
        actions: [
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
          _buildStatCard('Online Now', _todayAttendance.length.toString(), Icons.radar_rounded, isAccent: true),
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
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StaffDetailScreen(staff: staff))),
          ),
        );
      },
    );
  }
}
