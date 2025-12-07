
import { useRouter } from 'next/router';

import { useState, useEffect } from 'react';

export default function Reserve() {

  const router = useRouter();

  const { loan: loanId } = router.query;

  const [loan, setLoan] = useState(null);

  const [fullname, setFullname] = useState('');

  const [phone, setPhone] = useState('');

  const [checked, setChecked] = useState(false);

  const [msg, setMsg] = useState('');

  useEffect(()=> {

    if (!loanId) return;

    fetch(`/api/loans?id=${encodeURIComponent(loanId)}`).then(r=>r.json()).then(j=>{

      if (j.ok && j.loan) setLoan(j.loan);

      else setLoan(null);

    }).catch(()=>setLoan(null));

  }, [loanId]);

  const submit = async (e) => {

    e.preventDefault();

    if (!checked) { setMsg('لطفاً تایید کنید'); return; }

    if (!fullname || !phone) { setMsg('نام و موبایل لازم است'); return; }

    const res = await fetch('/api/reservations', { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({ loanId, fullname, phone })});

    const j = await res.json();

    if (!j.ok) setMsg(j.error || 'خطا');

    else {

      alert('همکاران ما تا دقایقی دیگر با شما تماس می‌گیرند');

      router.push('/dashboard');

    }

  };

  if (!loan) return <div className="container"><p className="kv">لطفاً وام را انتخاب کنید</p></div>;

  return (

    <div className="container">

      <div className="form-card">

        <h3>رزرو: {loan.title}</h3>

        <p>بانک: {loan.bank_logo ? (<img src={loan.bank_logo} style={{width:60}} />) : '—'}</p>

        <p>مبلغ: {loan.amount? Number(loan.amount).toLocaleString() + ' تومان' : ''}</p>

        <p>اقساط: {loan.installments} ماه</p>

        <form onSubmit={submit}>

          <input placeholder="نام و نام خانوادگی" value={fullname} onChange={e=>setFullname(e.target.value)} />

          <input placeholder="شماره موبایل" value={phone} onChange={e=>setPhone(e.target.value)} />

          <label><input type="checkbox" checked={checked} onChange={e=>setChecked(e.target.checked)} /> آیا از رزرو وام مطمئن هستید؟</label>

          <button className="reserve-btn" type="submit">ارسال رزرو</button>

        </form>

        <p style={{color:'red'}}>{msg}</p>

      </div>

    </div>

  );

}

