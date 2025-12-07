
import { getTokenFromReq, verifyToken } from '../../lib/auth';

import { supabaseServer } from '../../lib/supabaseServer';

export default async function handler(req, res) {

  const token = getTokenFromReq(req);

  if (!token) return res.json({ user: null });

  const data = verifyToken(token);

  if (!data) return res.json({ user: null });

  const { data: userRow } = await supabaseServer.from('users_vamto').select('id,phone,fullname,role').eq('id', Number(data.id)).maybeSingle();

  return res.json({ user: userRow || null });

}

