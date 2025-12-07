
import { useState } from 'react';

import Router from 'next/router';

import { getTokenFromReq, verifyToken } from '../../lib/auth';

export async function getServerSideProps({ req }) {

  const token = getTokenFromReq(req);

  const user = token ? verifyToken(token) : null;

  if (!user || user.role !== 'admin') {

    return { redirect: { destination: '/', permanent: false } };

  }

  return { props: {} };

}

export default function AdminPage() {

  const [title, setTitle] = useState('');

  const [amount, setAmount] = useState('');

  const [installments, setInstallments] = useState('');

  const [price, setPrice] = useState('');

  const [msg, setMsg] = useState('');

  async function submit(e) {

    e.preventDefault();

    setMsg('در حال ارسال...');

    try {

      const body = { title, amount: Number(amount), installments: Number(installments), price: Number(price) };

      const res = await fetch('/api/loans', { method: 'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify(body) });

      const j = await res.json();

      if (!j.ok) { setMsg(j.error || 'خطا'); return; }

      setMsg('ذخیره شد');

      setTimeout(()=>Router.reload(), 800);

    } catch (err) {

      setMsg(err.message || 'خطا');

    }

  }

  return (

    <div className="container">

      <div className="form-card">

        <h3>پنل مدیریت - افزودن وام</h3>

        <form onSubmit={submit}>

          <input placeholder="عنوان" value={title} onChange={e=>setTitle(e.target.value)} />

          <input type="number" placeholder="مبلغ (تومان)" value={amount} onChange={e=>setAmount(e.target.value)} />

          <input type="number" placeholder="اقساط (ماه)" value={installments} onChange={e=>setInstallments(e.target.value)} />

          <input type="number" placeholder="قیمت نهایی" value={price} onChange={e=>setPrice(e.target.value)} />

          <button className="reserve-btn" type="submit">افزودن وام</button>

        </form>

        <p className="kv">{msg}</p>

      </div>

    </div>

  );

}

