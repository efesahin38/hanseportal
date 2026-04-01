import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient('https://qlfdbkrmjzggoaxbnvij.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFsZmRia3JtanpnZ29heGJudmlqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM4NDg0MDYsImV4cCI6MjA4OTQyNDQwNn0.7Z_bcVZRY2d5WyqXSTMv6_0JXtro7UmFd_hLP_aGPE8');
  
  try {
    final plans = await supabase.from('operation_plans').select('''
      *,
      order:orders(id, title, order_number, site_address, customer:customers(id, name)),
      site_supervisor:users!operation_plans_site_supervisor_id_fkey(id, first_name, last_name),
      operation_plan_personnel(user_id, is_supervisor, users(id, first_name, last_name, role))
    ''');
    print('Plans count: ${plans.length}');
    if (plans.isNotEmpty) {
      print('First plan: ${plans.first}');
    }

    final p2 = await supabase.from('operation_plans').select();
    print('Raw operation_plans: ${p2.length}');

    final p3 = await supabase.from('operation_plan_personnel').select();
    print('Raw operation_plan_personnel: ${p3.length}');
  } catch (e) {
    print('Error: $e');
  }
}
