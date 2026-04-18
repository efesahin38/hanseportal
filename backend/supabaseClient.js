require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.warn("WARNING: SUPABASE_URL and SUPABASE_ANON_KEY must be provided in .env");
}

const supabase = createClient(supabaseUrl || 'https://placeholder.supabase.co', supabaseKey || 'placeholder');
const supabaseAdmin = createClient(supabaseUrl || 'https://placeholder.supabase.co', process.env.SUPABASE_SERVICE_KEY || 'placeholder');

module.exports = { supabase, supabaseAdmin };
