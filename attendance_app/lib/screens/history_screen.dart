import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/attendance_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final attendanceService = Provider.of<AttendanceService>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('History and Logs', style: TextStyle(letterSpacing: 0, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: attendanceService.getAttendanceHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.black));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.black.withValues(alpha: 0.05)),
                  const SizedBox(height: 16),
                  const Text(
                    'No activities yet',
                    style: TextStyle(color: Colors.black26, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ],
              ),
            );
          }

          final records = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            itemCount: records.length,
            itemBuilder: (context, index) {
              final record = records[index];
              final checkIn = DateTime.parse(record['check_in']);
              final checkOut = record['check_out'] != null
                  ? DateTime.parse(record['check_out'])
                  : null;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.03)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('EEEE, MMM d').format(checkIn).toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1, color: Colors.black38),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            checkOut != null 
                              ? '${DateFormat('hh:mm a').format(checkIn)} — ${DateFormat('hh:mm a').format(checkOut)}'
                              : '${DateFormat('hh:mm a').format(checkIn)} — ACTIVE',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                    if (checkOut == null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                      )
                    else
                         const Icon(Icons.check_circle_outline_rounded, color: Colors.black12, size: 20),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
