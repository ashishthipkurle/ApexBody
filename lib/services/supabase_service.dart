import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  // TODO: replace with your Supabase details
  final String supabaseUrl = 'https://uolzrncnaoccwnqbbwuy.supabase.co';
  final String supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVvbHpybmNuYW9jY3ducWJid3V5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUwMDgyOTMsImV4cCI6MjA3MDU4NDI5M30.cihslnZyGCl4TSxcx9EuoW5_6oEK7jzwvZumNgmwwLw';

  Future<void> init() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseKey,
    );
  }

  SupabaseClient get client => Supabase.instance.client;
}
