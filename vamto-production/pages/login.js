
import { useState } from 'react';

import { useRouter } from 'next/router';

export default function Login() {

  const [phone, setPhone] = useState('');

  const [password, setPassword] = useState('');

  const [msg, setMsg] = useState('');

  const router = useRouter();

  const submit = async (e) => {

    e.preventDefault();

    const phoneRegex = /^09\d{9}$/;

    if (!phoneRegex.test(phone)) { setMsg('شماره موبایل نامعتبر است'); return; }

    const res = await fetch('/api/auth/login', { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({ phone, password }) });

    const data = await res.json();

    if (!data.ok) setMsg(data.error || 'خطا');

    else router.push('/');

  };

  return (

    <div className="container">

      <div className="form-card">

        <h2>ورود</h2>

        <form onSubmit={submit}>

          <input placeholder="شماره موبایل" value={phone} onChange={e=>setPhone(e.target.value)} />

          <input placeholder="رمز عبور" type="password" value={password} onChange={e=>setPassword(e.target.value)} />

          <button type="submit" className="reserve-btn">ورود</button>

        </form>

        <p style={{color:'red'}}>{msg}</p>

      </div>

    </div>

  );

}

