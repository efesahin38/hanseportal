const { createClient } = require('@supabase/supabase-js');
const supabase = createClient(
  'https://qlfdbkrmjzggoaxbnvij.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFsZmRia3JtanpnZ29heGJudmlqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM4NDg0MDYsImV4cCI6MjA4OTQyNDQwNn0.7Z_bcVZRY2d5WyqXSTMv6_0JXtro7UmFd_hLP_aGPE8'
);
async function run() {
  const { data, error } = await supabase.from('departments').select('id, name, company_id');
  console.log(JSON.stringify(data, null, 2), error);
  
  // also check how inFilter works on relations
  const { data: q1, error: e1 } = await supabase.from('work_sessions').select('id, order:orders!inner(id, service_area_id)').in('order.service_area_id', [data[0].id]);
  console.log('Using order.service_area_id', e1?.message);
  
  const { data: q2, error: e2 } = await supabase.from('work_sessions').select('id, order:orders!inner(id, service_area_id)').in('orders.service_area_id', [data[0].id]);
  console.log('Using orders.service_area_id', e2?.message);
}
run();
