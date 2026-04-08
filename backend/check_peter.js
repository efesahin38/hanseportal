const { createClient } = require('@supabase/supabase-js');
const supabase = createClient(
  'https://qlfdbkrmjzggoaxbnvij.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFsZmRia3JtanpnZ29heGJudmlqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM4NDg0MDYsImV4cCI6MjA4OTQyNDQwNn0.7Z_bcVZRY2d5WyqXSTMv6_0JXtro7UmFd_hLP_aGPE8'
);
async function run() {
  const { data: users } = await supabase.from('users').select('id, first_name, last_name, role').ilike('first_name', '%Peter%');
  console.log('Peter User:', users);
  if (users && users.length > 0) {
    const { data: usa } = await supabase.from('user_service_areas').select('*, service_areas(id, name)').eq('user_id', users[0].id);
    console.log('Peter Service Areas:', usa);
  }
}
run();
