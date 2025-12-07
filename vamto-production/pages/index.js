
import LoanCard from '../components/LoanCard';

import { supabaseServer } from '../lib/supabaseServer';

import { useState, useMemo } from 'react';

import { useRouter } from 'next/router';

export async function getStaticProps() {

  const { data: loans } = await supabaseServer

    .from('loans_vamto')

    .select('*')

    .order('id', { ascending: false });

  const safe = (loans || []).map(l => ({

    ...l,

    amount: l.amount != null ? l.amount.toString() : l.amount,

    price: l.price != null ? l.price.toString() : l.price

  }));

  return { props: { loans: safe }, revalidate: 60 };

}

export default function Home({ loans }) {

  const router = useRouter();

  const [searchTerm, setSearchTerm] = useState('');

  const filteredLoans = useMemo(() => {

    const q = (searchTerm || '').trim();

    if (!q) return loans;

    const lowered = q.toLowerCase();

    return loans.filter(l => {

      if (l.title && l.title.toLowerCase().includes(lowered)) return true;

      if (String(l.amount || '').toLowerCase().includes(lowered)) return true;

      return false;

    });

  }, [loans, searchTerm]);

  const handleReserve = (id) => router.push(`/reserve?loan=${id}`);

  return (

    <div className="container">

      <div className="search-area">

        <input placeholder="جستجو: عنوان یا مبلغ..." value={searchTerm} onChange={e=>setSearchTerm(e.target.value)} onKeyDown={(e)=> e.key==='Enter' && e.preventDefault()} />

        <button className="search-btn" onClick={()=>{}}>جستجو</button>

      </div>

      <div className="titles">

        <div>بانک</div><div>عنوان</div><div>مبلغ</div><div>اقساط</div><div>قیمت</div>

      </div>

      <div className="loan-list">

        {filteredLoans.map(loan => <LoanCard key={loan.id} loan={loan} onReserve={handleReserve} />)}

      </div>

    </div>

  );

}

