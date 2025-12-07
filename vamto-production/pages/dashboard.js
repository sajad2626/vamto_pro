
import { supabaseServer } from '../lib/supabaseServer';

import { getTokenFromReq, verifyToken } from '../lib/auth';

export async function getServerSideProps({ req }) {

  const token = getTokenFromReq(req);

  const user = token ? verifyToken(token) : null;

  if (!user) return { redirect: { destination: '/login', permanent: false } };

  const { data: rawReservations } = await supabaseServer

    .from('reservations')

    .select('*, loans_vamto(*)')

    .eq('user_id', Number(user.id))

    .order('created_at', { ascending: false });

  const reservations = (rawReservations || []).map(r => ({

    ...r,

    loans_vamto: r.loans_vamto ? { ...r.loans_vamto, amount: r.loans_vamto.amount!=null? r.loans_vamto.amount.toString(): r.loans_vamto.amount, price: r.loans_vamto.price!=null? r.loans_vamto.price.toString(): r.loans_vamto.price } : null

  }));

  return { props: { reservations, user } };

}

export default function Dashboard({ reservations, user }) {

  return (

    <div className="container">

      <div className="form-card"><strong>{user.fullname}</strong><div className="kv">موبایل: {user.phone}</div></div>

      <h3>رزروهای من</h3>

      {reservations.length === 0 ? <p className="kv">رزروی یافت نشد.</p> : reservations.map(r => (

        <div key={r.id} className="loan-row">

          <div className="bank-icon">{r.loans_vamto?.bank_logo ? <img src={r.loans_vamto.bank_logo} style={{width:36,height:36,objectFit:'contain'}} /> : '🏛️'}</div>

          <div>

            <div className="amount" style={{fontSize:15}}>{r.loans_vamto?.title || 'وام حذف شده'}</div>

            <div className="kv">مبلغ: {r.loans_vamto ? Number(r.loans_vamto.amount).toLocaleString() : 0} تومان</div>

          </div>

          <div className="installments">{r.loans_vamto ? r.loans_vamto.installments : 0} ماهه</div>

          <div className="credit"><span className="yes">{r.status}</span></div>

          <div className="price center">{new Date(r.created_at).toLocaleString()}</div>

        </div>

      ))}

    </div>

  );

}

