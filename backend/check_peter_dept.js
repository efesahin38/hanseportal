const { createClient } = require('@supabase/supabase-js');
const supabase = createClient(
  'https://qlfdbkrmjzggoaxbnvij.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFsZmRia3JtanpnZ29heGJudmlqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM4NDg0MDYsImV4cCI6MjA4OTQyNDQwNn0.7Z_bcVZRY2d5WyqXSTMv6_0JXtro7UmFd_hLP_aGPE8'
);
async function run() {
  const { data: user } = await supabase.from('users').select('id, department_id, department:departments(name)').eq('id', 'bbbbbbbb-0000-0000-0000-000000000006').single();
  console.log('Peter User with Dept:', user);
}
run();
