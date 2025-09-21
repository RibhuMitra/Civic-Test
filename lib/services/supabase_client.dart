import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseClient {
  static SupabaseClient? _instance;

  SupabaseClient._();

  static SupabaseClient get instance {
    _instance ??= SupabaseClient._();
    return _instance!;
  }

  static Supabase get supabase => Supabase.instance;
  static SupabaseClient get client => supabase.client;
  static User? get currentUser => supabase.client.auth.currentUser;
  static Session? get currentSession => supabase.client.auth.currentSession;
}
