import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseService {
  static const String _fallbackUrl = 'https://ozxdyolgcmrfslgtxjgc.supabase.co';
  static const String _fallbackKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im96eGR5b2xnY21yZnNsZ3R4amdjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE5NDM2OTEsImV4cCI6MjA5NzUxOTY5MX0.cyzj-xvWc-lfG8XEcO0dr8u25ZioSNhefJsNpYKOgCk';

  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? _fallbackUrl;
  static String get supabaseKey => dotenv.env['SUPABASE_ANON_KEY'] ?? _fallbackKey;

  static Future<void> initialize() async {
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      // Silently catch env loading errors (e.g. 404 on web servers blocking dotfiles)
      // and proceed using the fallback constants.
    }
    
    // Ensure we use defaults if dotenv loaded but didn't contain the keys
    final url = supabaseUrl.isEmpty ? _fallbackUrl : supabaseUrl;
    final key = supabaseKey.isEmpty ? _fallbackKey : supabaseKey;

    await Supabase.initialize(
      url: url,
      anonKey: key,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
