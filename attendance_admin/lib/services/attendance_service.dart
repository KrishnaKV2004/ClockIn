import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class AttendanceService with ChangeNotifier {
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

  Future<List<dynamic>> getAllStaff() async {
    try {
      final response = await SupabaseService.client
          .from('profiles')
          .select()
          .order('full_name');
      debugPrint('Fetched ${response.length} staff members');
      return response;
    } catch (e) {
      debugPrint('Error fetching all staff: $e');
      return [];
    }
  }

  Future<void> _closePreviousCheckIns() async {
    try {
      final openRecords = await _client
          .from('attendance')
          .select()
          .isFilter('check_out', null);

      if (openRecords.isNotEmpty) {
        final now = DateTime.now();
        final List<Future> updates = [];
        for (var record in openRecords) {
          final checkInStr = record['check_in'];
          if (checkInStr == null) continue;
          final checkInTime = DateTime.parse(checkInStr).toLocal();

          // Check if check-in was on a previous day
          if (checkInTime.year < now.year ||
              (checkInTime.year == now.year && checkInTime.month < now.month) ||
              (checkInTime.year == now.year && checkInTime.month == now.month && checkInTime.day < now.day)) {

            DateTime checkOutTime = DateTime(
              checkInTime.year,
              checkInTime.month,
              checkInTime.day,
              22,
              0,
              0,
            );
            if (checkOutTime.isBefore(checkInTime)) {
              checkOutTime = checkInTime.add(const Duration(minutes: 5));
            }

            updates.add(
              _client.from('attendance').update({
                'check_out': checkOutTime.toIso8601String(),
              }).eq('id', record['id']).then((_) {}, onError: (e) {
                debugPrint('Error auto-closing record ${record['id']}: $e');
              }),
            );
          }
        }
        if (updates.isNotEmpty) {
          await Future.wait(updates).timeout(const Duration(seconds: 5));
        }
      }
    } catch (e) {
      debugPrint('Error auto-closing old check-ins: $e');
    }
  }

  Future<List<dynamic>> getAllAttendanceHistory() async {
    try {
      // Fire-and-forget: run auto-closing in the background without blocking the UI
      _closePreviousCheckIns();

      // Optimize: Only fetch records within the last 30 days or the current month
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      final limitDate = startOfMonth.isBefore(thirtyDaysAgo) ? startOfMonth : thirtyDaysAgo;

      final response = await SupabaseService.client
          .from('attendance')
          .select('*')
          .gte('check_in', limitDate.toIso8601String());

      debugPrint('FETCH ATTEMPT: Optimized records found: ${response.length}');
      return response;
    } catch (e) {
      debugPrint('Error fetching all attendance history: $e');
      return [];
    }
  }

  Future<List<dynamic>> getStaffAttendance(String userId) async {
    try {
      // Fire-and-forget: run auto-closing in the background without blocking the UI
      _closePreviousCheckIns();

      final response = await SupabaseService.client
          .from('attendance')
          .select()
          .eq('user_id', userId)
          .order('check_in', ascending: false);
      debugPrint('Fetched ${response.length} records for staff ID: $userId');
      return response;
    } catch (e) {
      debugPrint('Error fetching staff attendance: $e');
      return [];
    }
  }

  Future<void> addStaff(String name, String email, String password) async {
    try {
      // 1. Create a temporary client with no-op storage to avoid logging out the admin
      // and to prevent the PKCE 'asyncStorage != null' error.
      final tempClient = SupabaseClient(
        SupabaseService.supabaseUrl,
        SupabaseService.supabaseKey,
        authOptions: AuthClientOptions(
          pkceAsyncStorage: _NoopStorage(),
        ),
      );

      // 2. Sign up the user
      final AuthResponse res = await tempClient.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': name,
        },
      );

      final user = res.user;
      if (user == null) throw Exception('Failed to create user');

      // 3. Insert into profiles table
      await _client.from('profiles').upsert({
        'id': user.id,
        'full_name': name,
        'updated_at': DateTime.now().toIso8601String(),
      });

      notifyListeners();
    } catch (e) {
      debugPrint('Error adding staff: $e');
      rethrow;
    }
  }

  Future<void> removeStaff(String userId) async {
    // First remove attendance records
    await SupabaseService.client.from('attendance').delete().eq('user_id', userId);
    // Then remove profile
    await SupabaseService.client.from('profiles').delete().eq('id', userId);
  }

  // Realtime Stream for attendance
  Stream<List<Map<String, dynamic>>> get attendanceStream {
    return _client
        .from('attendance')
        .stream(primaryKey: ['id'])
        .order('check_in', ascending: false);
  }
}

// Simple no-op storage for temporary Supabase clients
class _NoopStorage extends GotrueAsyncStorage {
  @override
  Future<void> removeItem({required String key}) async {}
  @override
  Future<String?> getItem({required String key}) async => null;
  @override
  Future<void> setItem({required String key, required String value}) async {}
}
