import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'services/supabase_service.dart';
import 'services/attendance_service.dart';
import 'services/profile_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Note: App will fail if keys are not set in SupabaseService
  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('Supabase Init Error: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        Provider<AttendanceService>(create: (_) => AttendanceService()),
        Provider<ProfileService>(create: (_) => ProfileService()),
      ],
      child: const AttendanceApp(),
    ),
  );
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Moon Attendance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.outfitTextTheme(
          Theme.of(context).textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SupabaseService.client.auth.currentSession;
    
    if (session == null) {
      return const LoginScreen();
    } else {
      return const HomeScreen();
    }
  }
}
