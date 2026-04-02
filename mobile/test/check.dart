import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final client = SupabaseClient(
    'https://qlfdbkrmjzggoaxbnvij.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFsZmRia3JtanpnZ29heGJudmlqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM4NDg0MDYsImV4cCI6MjA4OTQyNDQwNn0.7Z_bcVZRY2d5WyqXSTMv6_0JXtro7UmFd_hLP_aGPE8',
  );

  print('=== CHECKING CUSTOMERS ===');
  try {
    final data = await client.from('customers').select('''
      *,
      company:companies(id, name, short_name),
      customer_contacts(*)
    ''').order('name');
    print('Total Customers: ${data.length}');
  } catch (e) {
    print('🚨 ERROR Customers: $e');
  }

  print('=== CHECKING SERVICE AREAS ===');
  try {
    final areas = await client.from('service_areas').select().eq('is_active', true).order('name');
    print('Total Service Areas: ${areas.length}');
  } catch (e) {
    print('🚨 ERROR Service Areas: $e');
  }
}
