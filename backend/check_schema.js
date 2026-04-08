const { createClient } = require('@supabase/supabase-js');
const supabase = createClient(
  'https://qlfdbkrmjzggoaxbnvij.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFsZmRia3JtanpnZ29heGJudmlqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM4NDg0MDYsImV4cCI6MjA4OTQyNDQwNn0.7Z_bcVZRY2d5WyqXSTMv6_0JXtro7UmFd_hLP_aGPE8'
);
async function run() {
  // Check service_areas table
  const { data: sa } = await supabase.from('service_areas').select('*').limit(1);
  console.log('Service Areas Sample:', sa);
  
  // Check departments table
  const { data: dept } = await supabase.from('departments').select('*').limit(1);
  console.log('Departments Sample:', sa);
}
run();
