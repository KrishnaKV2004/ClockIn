import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class AttendanceService {
  final SupabaseClient _client = SupabaseService.client;

  Future<void> checkIn(double lat, double lng) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    await _client.from('attendance').insert({
      'user_id': user.id,
      'check_in': DateTime.now().toIso8601String(),
      'latitude': lat,
      'longitude': lng,
    });
  }

  Future<void> checkOut() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Find the latest check-in that doesn't have a check-out
    final lastRecord = await _client
        .from('attendance')
        .select()
        .eq('user_id', user.id)
        .isFilter('check_out', null)
        .order('check_in', ascending: false)
        .limit(1)
        .maybeSingle();

    if (lastRecord == null) throw Exception('No active check-in found');

    await _client.from('attendance').update({
      'check_out': DateTime.now().toIso8601String(),
    }).eq('id', lastRecord['id']);
  }

  Future<Map<String, dynamic>?> getTodayAttendance() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();

    try {
      final response = await _client
          .from('attendance')
          .select()
          .eq('user_id', user.id)
          .gte('check_in', startOfDay)
          .order('check_in', ascending: false)
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      return response;
    } catch (e) {
      debugPrint('getTodayAttendance error: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getAttendanceHistory() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    return await _client
        .from('attendance')
        .select()
        .eq('user_id', user.id)
        .order('check_in', ascending: false);
  }
}
