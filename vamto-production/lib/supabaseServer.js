
import { createClient } from '@supabase/supabase-js';

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;

const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!url || !serviceRoleKey) {

  throw new Error('Missing Supabase URL or Service Role Key in env');

}

export const supabaseServer = createClient(url, serviceRoleKey);

