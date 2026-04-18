const { createClient } = require('@supabase/supabase-js');
const supabase = createClient(
  'https://qlfdbkrmjzggoaxbnvij.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFsZmRia3JtanpnZ29heGJudmlqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM4NDg0MDYsImV4cCI6MjA4OTQyNDQwNn0.7Z_bcVZRY2d5WyqXSTMv6_0JXtro7UmFd_hLP_aGPE8'
);
async function run() {
  const { data: users } = await supabase.from('users').select('id, first_name, last_name, company_id, department_id, departments(id, name, code, company_id)');
  console.log("USERS AND DEPARTMENTS:");
  console.log(JSON.stringify(users, null, 2));

  const { data: comps } = await supabase.from('companies').select('id, name');
  console.log("\nCOMPANIES IN DB:");
  console.log(JSON.stringify(comps, null, 2));
}
run();
