import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseManager {
  static const String _supabaseUrl = 'https://jqmlivtchooqbrwlsdzo.supabase.co';
  static const String _supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpxbWxpdnRjaG9vcWJyd2xzZHpvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE2NTQ2NTcsImV4cCI6MjA3NzIzMDY1N30.VIqjh70dqKfy5iP4Sb2jqvNOhMrFrbPA0fVP1Lqh4Bc';

  static Future<void> init() async {

    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabaseAnonKey,
      debug: false, // Set to true if you want to see logs in console
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}