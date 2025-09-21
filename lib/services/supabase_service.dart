import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseService? _instance;

  SupabaseService._();

  static SupabaseService get instance {
    _instance ??= SupabaseService._();
    return _instance!;
  }

  static Supabase get supabase => Supabase.instance;
  static SupabaseClient get client => supabase.client;
  static User? get currentUser => supabase.client.auth.currentUser;
  static Session? get currentSession => supabase.client.auth.currentSession;
}
