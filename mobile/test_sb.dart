import 'package:supabase/supabase.dart';
Future<void> main() async {
  final supabase = SupabaseClient('https://qlfdbkrmjzggoaxbnvij.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFsZmRia3JtanpnZ29heGJudmlqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM4NDg0MDYsImV4cCI6MjA4OTQyNDQwNn0.7Z_bcVZRY2d5WyqXSTMv6_0JXtro7UmFd_hLP_aGPE8');
  final res2 = await supabase.from('orders').select('id, service_area_id');
  print('orders: \$res2');
}
