const { createClient } = require('@supabase/supabase-js');
const supabase = createClient(
  'https://qlfdbkrmjzggoaxbnvij.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFsZmRia3JtanpnZ29heGJudmlqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM4NDg0MDYsImV4cCI6MjA4OTQyNDQwNn0.7Z_bcVZRY2d5WyqXSTMv6_0JXtro7UmFd_hLP_aGPE8'
);

async function run() {
  const parentId = 'aaaaaaaa-1111-1111-1111-111111111111';

  // 1. Insert Companies
  const newCompanies = [
    { name: 'Hanse Reinigung GmbH', short_name: 'Reinigung', company_type: 'GmbH', relation_type: 'subsidiary', parent_company_id: parentId },
    { name: 'Hanse Rail GmbH', short_name: 'Rail', company_type: 'GmbH', relation_type: 'subsidiary', parent_company_id: parentId },
    { name: 'Hanse Hotelservice GmbH', short_name: 'Hotelservice', company_type: 'GmbH', relation_type: 'subsidiary', parent_company_id: parentId },
    { name: 'Hanse Personal GmbH', short_name: 'Personal', company_type: 'GmbH', relation_type: 'subsidiary', parent_company_id: parentId }
  ];

  for (let c of newCompanies) {
    const { data: existing } = await supabase.from('companies').select('*').eq('name', c.name);
    if (!existing || existing.length === 0) {
      await supabase.from('companies').insert(c);
      console.log('Inserted', c.name);
    }
  }

  const { data: allComps } = await supabase.from('companies').select('*');

  const getCompId = (name) => allComps.find(x => x.name === name)?.id;
  
  // 2. Map Departments to these companies
  const deptUpdates = [
    { code: 'reinigung', comp: 'Hanse Reinigung GmbH' },
    { code: 'rail', comp: 'Hanse Rail GmbH' },
    { code: 'hotel', comp: 'Hanse Hotelservice GmbH' },
    { code: 'personal', comp: 'Hanse Personal GmbH' },
  ];

  for (let u of deptUpdates) {
    const compId = getCompId(u.comp);
    if (compId) {
      await supabase.from('departments').update({ company_id: compId }).eq('code', u.code);
      console.log(`Updated department ${u.code} to company ${compId}`);
    }
  }
}
run();
