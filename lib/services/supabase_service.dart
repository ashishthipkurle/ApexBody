import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  // TODO: replace with your Supabase details
  final String supabaseUrl = "";
  final String supabaseKey = "";

  Future<void> init() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseKey,
    );
  }

  SupabaseClient get client => Supabase.instance.client;
}
