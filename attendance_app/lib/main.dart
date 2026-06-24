import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF000000),
          onPrimary: Colors.white,
          secondary: Color(0xFF64748B),
          surface: Colors.white,
          onSurface: Color(0xFF0F172A),
        ),
        textTheme: GoogleFonts.outfitTextTheme(
          Theme.of(context).textTheme.apply(bodyColor: const Color(0xFF0F172A), displayColor: const Color(0xFF0F172A)),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
          centerTitle: true,
          titleTextStyle: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  // On web, Supabase restores the session asynchronously.
  // We start as "loading" and resolve once the first auth event fires.
  bool _isLoading = kIsWeb;
  Session? _session;

  @override
  void initState() {
    super.initState();
    // Read any already-restored session immediately
    _session = SupabaseService.client.auth.currentSession;

    SupabaseService.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      setState(() {
        _session = data.session;
        _isLoading = false;
      });
    });

    // Fallback: if not on web, stop loading immediately
    if (!kIsWeb) {
      _isLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Colors.black)),
      );
    }
    return _session == null ? const LoginScreen() : const HomeScreen();
  }
}
