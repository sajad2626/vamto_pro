#!/usr/bin/env bash

set -e

# create_vamto_supabase.sh

# Script builds a full Next.js + Supabase project skeleton ready for production (Supabase only).

# Usage:

#   chmod +x create_vamto_supabase.sh

#   ./create_vamto_supabase.sh

#

# After run:

#  - fill .env.local

#  - run SQL in Supabase (sql/setup.sql)

#  - npm install && npm run dev

PROJECT_DIR="vamto-production"

if [ -d "$PROJECT_DIR" ]; then

  echo "Removing existing $PROJECT_DIR ..."

  rm -rf "$PROJECT_DIR"

fi

mkdir -p "$PROJECT_DIR"

cd "$PROJECT_DIR"

echo "==> creating package.json"

cat > package.json <<'JSON'

{

  "name": "vamto-production",

  "version": "1.0.0",

  "private": true,

  "scripts": {

    "dev": "next dev -p 3000",

    "build": "next build",

    "start": "next start -p 3000"

  },

  "dependencies": {

    "@supabase/supabase-js": "^2.43.4",

    "bcryptjs": "^2.4.3",

    "cookie": "^0.5.0",

    "formidable": "^3.7.1",

    "jsonwebtoken": "^9.0.0",

    "next": "13.4.19",

    "react": "18.2.0",

    "react-dom": "18.2.0"

  }

}

JSON

echo "==> creating next.config.js with security headers"

cat > next.config.js <<'JS'

/** next.config.js */

module.exports = {

  reactStrictMode: true,

  swcMinify: true,

  async headers() {

    return [

      {

        source: "/(.*)",

        headers: [

          { key: "X-Frame-Options", value: "DENY" },

          { key: "X-Content-Type-Options", value: "nosniff" },

          { key: "Referrer-Policy", value: "no-referrer-when-downgrade" },

          { key: "Permissions-Policy", value: "geolocation=()" },

          { key: "Content-Security-Policy", value: "default-src 'self'; img-src 'self' data: https:; script-src 'self'; style-src 'self' 'unsafe-inline';" }

        ]

      }

    ];

  }

};

JS

echo "==> .env.example"

cat > .env.example <<'ENV'

# Supabase (public) URL and anon key for client-side usage

NEXT_PUBLIC_SUPABASE_URL="https://your-project.supabase.co"

NEXT_PUBLIC_SUPABASE_ANON_KEY="YOUR_ANON_KEY"

# Service Role Key (ONLY on server; never push to client)

SUPABASE_SERVICE_ROLE_KEY="YOUR_SERVICE_ROLE_KEY"

# JWT secret used to sign session cookie (min 32 chars)

JWT_SECRET="replace_with_a_long_random_secret_min_32_chars"

# Base URL

NEXT_PUBLIC_BASE_URL="http://localhost:3000"

ENV

echo "==> creating folders"

mkdir -p sql lib utils context components pages/api pages/admin styles public/uploads

echo "==> sql/setup.sql (with RLS base & notes)"

cat > sql/setup.sql <<'SQL'

-- sql/setup.sql

-- Run this in Supabase SQL editor.

-- Creates tables and enables RLS; write operations are intended via server API (service role).

create table if not exists users_vamto (

  id serial primary key,

  phone text unique not null,

  password text not null,

  fullname text,

  role text default 'user',

  created_at timestamptz default now()

);

create table if not exists bank_logos (

  id serial primary key,

  title text,

  image_url text,

  created_at timestamptz default now()

);

create table if not exists loans_vamto (

  id serial primary key,

  title text not null,

  amount bigint,

  installments int,

  price bigint,

  bank_logo text,

  is_credit boolean default false,

  created_at timestamptz default now()

);

create table if not exists reservations (

  id serial primary key,

  user_id int references users_vamto(id) on delete set null,

  loan_id int references loans_vamto(id) on delete set null,

  fullname text,

  phone text,

  status text default 'pending',

  created_at timestamptz default now()

);

-- Enable RLS

alter table users_vamto enable row level security;

alter table bank_logos enable row level security;

alter table loans_vamto enable row level security;

alter table reservations enable row level security;

-- Public read for loans & logos

create policy if not exists "public_select_loans" on loans_vamto for select using (true);

create policy if not exists "public_select_logos" on bank_logos for select using (true);

-- Disable direct writes from anon by not adding insert policies here.

-- We use server API (SERVICE ROLE) to perform inserts/updates/deletes.

SQL

echo "==> lib/supabaseClient.js"

cat > lib/supabaseClient.js <<'JS'

import { createClient } from '@supabase/supabase-js';

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;

const anon = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

export const supabase = createClient(url, anon);

JS

echo "==> lib/supabaseServer.js"

cat > lib/supabaseServer.js <<'JS'

import { createClient } from '@supabase/supabase-js';

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;

const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!url || !serviceRoleKey) {

  throw new Error('Missing Supabase URL or Service Role Key in env');

}

export const supabaseServer = createClient(url, serviceRoleKey);

JS

echo "==> lib/auth.js (JWT cookie helpers)"

cat > lib/auth.js <<'JS'

import jwt from 'jsonwebtoken';

import cookie from 'cookie';

const SECRET = process.env.JWT_SECRET || 'dev_secret_change_me_change';

export function signToken(payload) {

  return jwt.sign(payload, SECRET, { expiresIn: '30d' });

}

export function verifyToken(token) {

  try {

    return jwt.verify(token, SECRET);

  } catch (e) {

    return null;

  }

}

export function setTokenCookie(res, token) {

  const serialized = cookie.serialize('token', token, {

    httpOnly: true,

    secure: process.env.NODE_ENV === 'production',

    sameSite: 'lax',

    path: '/',

    maxAge: 60 * 60 * 24 * 30

  });

  res.setHeader('Set-Cookie', serialized);

}

export function clearTokenCookie(res) {

  const serialized = cookie.serialize('token', '', {

    httpOnly: true,

    secure: process.env.NODE_ENV === 'production',

    sameSite: 'lax',

    path: '/',

    maxAge: 0

  });

  res.setHeader('Set-Cookie', serialized);

}

export function getTokenFromReq(req) {

  const hdr = req.headers?.cookie || '';

  const cookies = cookie.parse(hdr || '');

  return cookies.token || null;

}

JS

echo "==> utils/apiResponse.js"

cat > utils/apiResponse.js <<'JS'

export const handleError = (res, error, status = 500) => {

  const message = error?.message || error || 'Internal Server Error';

  console.error('[API ERROR]', message);

  return res.status(status).json({ ok: false, error: message });

};

export const handleSuccess = (res, data = {}, status = 200) => {

  return res.status(status).json({ ok: true, ...data });

};

JS

echo "==> context/AuthContext.js"

cat > context/AuthContext.js <<'JS'

import { createContext, useContext, useEffect, useState } from 'react';

const AuthContext = createContext({ user: null, loading: true, setUser: ()=>{} });

export const AuthProvider = ({ children }) => {

  const [user, setUser] = useState(null);

  const [loading, setLoading] = useState(true);

  useEffect(() => {

    let mounted = true;

    fetch('/api/me')

      .then(r => r.json())

      .then(j => {

        if (!mounted) return;

        setUser(j.user || null);

      })

      .catch(() => setUser(null))

      .finally(() => mounted && setLoading(false));

    return () => { mounted = false; };

  }, []);

  return (

    <AuthContext.Provider value={{ user, setUser, loading }}>

      {children}

    </AuthContext.Provider>

  );

};

export const useAuth = () => useContext(AuthContext);

JS

echo "==> components/Header.jsx"

cat > components/Header.jsx <<'JS'

import Link from "next/link";

import { useAuth } from "../context/AuthContext";

export default function Header() {

  const { user, loading } = useAuth();

  return (

    <header style={{ background: "#0a67b5", color: "white", padding: 12 }}>

      <div style={{ maxWidth: 1100, margin: "0 auto", display: "flex", justifyContent: "space-between", alignItems: "center" }}>

        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>

          <div style={{ width: 40, height: 40, borderRadius: 8, background: "#eaf6ff", color: "#0a67b5", display: "flex", alignItems: "center", justifyContent: "center", fontWeight: 800 }}>V</div>

          <div style={{ fontWeight: 800, fontSize: 18 }}>وامتو</div>

        </div>

        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>

          <Link href="/">صفحه اصلی</Link>

          <Link href="/list">وام‌ها</Link>

          <Link href="/contact">تماس</Link>

          {loading ? (

            <div style={{ width: 80, height: 20, background: "rgba(255,255,255,0.12)", borderRadius: 4 }} />

          ) : user ? (

            <>

              <Link href="/dashboard">رزروها</Link>

              {user.role === "admin" && <Link href="/admin">پنل</Link>}

              <Link href="/api/auth/logout">خروج</Link>

            </>

          ) : (

            <>

              <Link href="/login">ورود</Link>

              <Link href="/signup">ثبت نام</Link>

            </>

          )}

          <div style={{ fontSize: 22 }}>☰</div>

        </div>

      </div>

    </header>

  );

}

JS

echo "==> components/LoanCard.jsx"

cat > components/LoanCard.jsx <<'JS'

export default function LoanCard({ loan, onReserve }) {

  return (

    <div className="loan-row" style={{ position: "relative" }}>

      {loan.is_credit && <div className="credit-badge">اعتباری</div>}

      <div style={{ display: "flex", alignItems: "center", gap: 12 }}>

        <div className="bank-icon">

          {loan.bank_logo ? <img src={loan.bank_logo} style={{ width: 44, height: 44, objectFit: "contain" }} /> : "🏦"}

        </div>

      </div>

      <div style={{ flex: 1 }}>

        <div style={{ fontWeight: 800 }}>{loan.title}</div>

      </div>

      <div style={{ width: 160 }}>

        <div className="amount">{loan.amount!=null? Number(loan.amount).toLocaleString()+' تومان':''}</div>

        <div className="kv">{loan.installments} ماهه</div>

      </div>

      <div style={{ width: 120, textAlign: "center" }}>

        <div className="price">{loan.price!=null? Number(loan.price).toLocaleString()+' تومان':''}</div>

      </div>

      <div style={{ width: 100 }}>

        <button className="reserve-btn" onClick={() => onReserve(loan.id)}>رزرو</button>

      </div>

    </div>

  );

}

JS

echo "==> components/Footer.jsx"

cat > components/Footer.jsx <<'JS'

export default function Footer() {

  return (

    <footer style={{ padding: 20, textAlign: "center", color: "#666" }}>

      © {new Date().getFullYear()} وامتو

    </footer>

  );

}

JS

echo "==> styles/globals.css"

cat > styles/globals.css <<'CSS'

:root{

  --blue:#2fa1ff;

  --blue-dark:#0a67b5;

  --green:#0ca651;

  --muted:#6b7280;

  --bg:#f6f9ff;

}

html,body{

  margin:0;

  padding:0;

  font-family: Vazirmatn, system-ui, -apple-system, "Segoe UI", Roboto, Arial;

  direction: rtl;

  background: var(--bg);

  color: #111;

}

.container{ max-width:1100px; margin:0 auto; padding:20px; }

.search-area{ margin:16px auto 24px; display:flex; gap:8px; background:#eaf6ff; padding:10px; border-radius:12px; }

.search-area input{ flex:1; border:0; padding:10px; border-radius:8px; background:transparent; outline:none; }

.search-btn{ background:var(--blue-dark); color:#fff; border:0; padding:8px 12px; border-radius:8px; cursor:pointer; }

.titles{ display:grid; grid-template-columns:60px 1fr 160px 120px 100px; gap:12px; padding:12px 10px; color:var(--muted); font-weight:700; }

.loan-list{ display:flex; flex-direction:column; gap:12px; }

.loan-row{ background:#fff; border-radius:12px; padding:12px; box-shadow:0 8px 30px rgba(2,6,23,0.06); display:grid; grid-template-columns:60px 1fr 160px 120px 100px; gap:12px; align-items:center; position:relative; }

.bank-icon{ width:48px; height:48px; border-radius:10px; display:flex; align-items:center; justify-content:center; background:#f3f8ff; color:var(--blue); font-size:20px; }

.amount{ font-weight:800; color:#111; font-size:17px; }

.installments{ color:var(--muted); }

.credit-badge{ position:absolute; left:8px; top:8px; width:34px; height:34px; clip-path: polygon(0 0, 100% 0, 0 100%); background:linear-gradient(180deg,#25b75a,#18a64a); color:#fff; font-size:10px; display:flex; align-items:flex-start; justify-content:flex-end; padding:5px 5px 0 0; }

.price{ color:var(--green); font-weight:800; text-align:center; }

.reserve-btn{ background:var(--green); color:white; border:0; padding:8px 12px; border-radius:10px; cursor:pointer; font-weight:700; }

.form-card{ background:#fff; padding:14px; border-radius:12px; box-shadow:0 8px 30px rgba(2,6,23,0.06); max-width:680px; margin:18px auto; }

.kv{ font-size:13px; color:var(--muted); }

@media (max-width:900px){ .titles{ display:none } .loan-row{ grid-template-columns:1fr; gap:8px } }

CSS

echo "==> pages/_app.js"

cat > pages/_app.js <<'JS'

import '../styles/globals.css';

import Header from '../components/Header';

import Footer from '../components/Footer';

import { AuthProvider, useAuth } from '../context/AuthContext';

function AppWrapper({ Component, pageProps }) {

  const { loading } = useAuth();

  if (loading) {

    return <div style={{padding:40,textAlign:'center'}}>در حال بارگذاری...</div>;

  }

  return (

    <>

      <Header />

      <Component {...pageProps} />

      <Footer />

    </>

  );

}

export default function MyApp(props) {

  return (

    <AuthProvider>

      <AppWrapper {...props} />

    </AuthProvider>

  );

}

JS

echo "==> pages/index.js (ISR + client filter)"

cat > pages/index.js <<'JS'

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

JS

echo "==> pages/login.js"

cat > pages/login.js <<'JS'

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

JS

echo "==> pages/signup.js"

cat > pages/signup.js <<'JS'

import { useState } from 'react';

import { useRouter } from 'next/router';

export default function Signup() {

  const [phone, setPhone] = useState('');

  const [fullname, setFullname] = useState('');

  const [password, setPassword] = useState('');

  const [msg, setMsg] = useState('');

  const router = useRouter();

  const submit = async (e) => {

    e.preventDefault();

    const phoneRegex = /^09\d{9}$/;

    if (!phoneRegex.test(phone)) { setMsg('شماره موبایل نامعتبر است'); return; }

    const res = await fetch('/api/auth/signup', { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({ phone, fullname, password }) });

    const data = await res.json();

    if (!data.ok) setMsg(data.error || 'خطا');

    else router.push('/');

  };

  return (

    <div className="container">

      <div className="form-card">

        <h2>ثبت نام</h2>

        <form onSubmit={submit}>

          <input placeholder="نام کامل" value={fullname} onChange={e=>setFullname(e.target.value)} />

          <input placeholder="شماره موبایل" value={phone} onChange={e=>setPhone(e.target.value)} />

          <input placeholder="رمز عبور" type="password" value={password} onChange={e=>setPassword(e.target.value)} />

          <button type="submit" className="reserve-btn">ثبت نام</button>

        </form>

        <p style={{color:'red'}}>{msg}</p>

      </div>

    </div>

  );

}

JS

echo "==> pages/reserve.js"

cat > pages/reserve.js <<'JS'

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

JS

echo "==> pages/dashboard.js"

cat > pages/dashboard.js <<'JS'

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

JS

echo "==> pages/contact.js"

cat > pages/contact.js <<'JS'

export default function Contact() {

  return (

    <div className="container">

      <div className="form-card">

        <h3>راه‌های ارتباطی</h3>

        <p>ایتا: <a href="https://eitaa.com/vamtopv" target="_blank" rel="noreferrer">vamtopv</a></p>

      </div>

    </div>

  );

}

JS

echo "==> pages/admin/index.js (SSR protected admin)"

cat > pages/admin/index.js <<'JS'

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

JS

echo "==> pages/admin/banks.js (SSR protected logos manager)"

cat > pages/admin/banks.js <<'JS'

import { useEffect, useState } from 'react';

import { getTokenFromReq, verifyToken } from '../../lib/auth';

export async function getServerSideProps({ req }) {

  const token = getTokenFromReq(req);

  const user = token ? verifyToken(token) : null;

  if (!user || user.role !== 'admin') {

    return { redirect: { destination: '/', permanent: false } };

  }

  return { props: {} };

}

export default function AdminBanksPage() {

  const [title, setTitle] = useState('');

  const [file, setFile] = useState(null);

  const [logos, setLogos] = useState([]);

  const [loading, setLoading] = useState(false);

  const fetchLogos = async () => {

    const res = await fetch('/api/admin/bank-logos');

    const j = await res.json();

    if (j.ok) setLogos(j.logos || []);

  };

  useEffect(()=>{ fetchLogos(); }, []);

  const addLogo = async () => {

    if(!title || !file) return alert('نام و فایل لازم است');

    if (loading) return;

    setLoading(true);

    const form = new FormData();

    form.append('file', file);

    form.append('title', title);

    const res = await fetch('/api/admin/bank-logos', { method: 'POST', body: form });

    const j = await res.json();

    setLoading(false);

    if(!j.ok) return alert(j.error || 'upload failed');

    setTitle(''); setFile(null); fetchLogos();

  };

  const deleteLogo = async (id) => {

    if(!confirm('حذف شود؟')) return;

    const res = await fetch(`/api/admin/bank-logos?id=${id}`, { method: 'DELETE' });

    const j = await res.json();

    if (j.ok) fetchLogos(); else alert(j.error || 'خطا');

  };

  return (

    <div className="container">

      <div className="form-card">

        <h3>مدیریت لوگوها</h3>

        <input placeholder="نام بانک" value={title} onChange={e=>setTitle(e.target.value)} />

        <input type="file" accept="image/*" onChange={e=>setFile(e.target.files[0])} />

        <button className="reserve-btn" onClick={addLogo} disabled={loading}>{loading ? 'در حال آپلود...' : 'افزودن لوگو'}</button>

      </div>

      <div>

        {logos.map(l=>(

          <div key={l.id} style={{display:'flex',gap:12,alignItems:'center',padding:8,borderBottom:'1px solid #eee'}}>

            <img src={l.image_url} style={{width:48,height:48,objectFit:'contain'}} />

            <div style={{flex:1}}>{l.title}</div>

            <button onClick={()=>deleteLogo(l.id)} style={{background:'#ef4444',color:'#fff',border:0,padding:'6px 8px',borderRadius:6}}>حذف</button>

          </div>

        ))}

      </div>

    </div>

  );

}

JS

echo "==> API: /api/me"

cat > pages/api/me.js <<'JS'

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

JS

echo "==> API: auth/signup, auth/login, auth/logout"

cat > pages/api/auth/signup.js <<'JS'

import { supabaseServer } from '../../../lib/supabaseServer';

import bcrypt from 'bcryptjs';

import { signToken, setTokenCookie } from '../../../lib/auth';

import { handleError, handleSuccess } from '../../../utils/apiResponse';

export default async function handler(req, res) {

  if (req.method !== 'POST') return res.status(405).json({ ok:false, error:'Method not allowed' });

  try {

    const { phone, password, fullname } = req.body;

    const phoneRegex = /^09\d{9}$/;

    if (!phoneRegex.test(phone)) return res.status(400).json({ ok:false, error: 'شماره موبایل نامعتبر است' });

    if (!password || password.length < 4) return res.status(400).json({ ok:false, error: 'رمز عبور باید حداقل ۴ کاراکتر باشد' });

    const { data: exists } = await supabaseServer.from('users_vamto').select('*').eq('phone', phone).maybeSingle();

    if (exists) return res.status(400).json({ ok:false, error: 'این شماره قبلاً ثبت شده' });

    const hashed = await bcrypt.hash(password, 10);

    const { data, error } = await supabaseServer.from('users_vamto').insert({ phone, password: hashed, fullname, role:'user' }).select().single();

    if (error) return handleError(res, error);

    const token = signToken({ id: data.id, phone: data.phone, role: data.role });

    setTokenCookie(res, token);

    return handleSuccess(res, { user: { id: data.id, phone: data.phone, fullname: data.fullname, role: data.role } });

  } catch (e) {

    return handleError(res, e);

  }

}

JS

cat > pages/api/auth/login.js <<'JS'

import { supabaseServer } from '../../../lib/supabaseServer';

import bcrypt from 'bcryptjs';

import { signToken, setTokenCookie } from '../../../lib/auth';

import { handleError, handleSuccess } from '../../../utils/apiResponse';

export default async function handler(req, res) {

  if (req.method !== 'POST') return res.status(405).json({ ok:false, error:'Method not allowed' });

  try {

    const { phone, password } = req.body;

    const phoneRegex = /^09\d{9}$/;

    if (!phoneRegex.test(phone)) return res.status(400).json({ ok:false, error: 'شماره موبایل نامعتبر است' });

    const { data: user } = await supabaseServer.from('users_vamto').select('*').eq('phone', phone).maybeSingle();

    if (!user) return res.status(400).json({ ok:false, error: 'کاربر یافت نشد' });

    const ok = await bcrypt.compare(password, user.password);

    if (!ok) return res.status(400).json({ ok:false, error: 'رمز عبور اشتباه است' });

    const token = signToken({ id: user.id, phone: user.phone, role: user.role });

    setTokenCookie(res, token);

    return handleSuccess(res, { user: { id: user.id, phone: user.phone, fullname: user.fullname, role: user.role } });

  } catch (e) {

    return handleError(res, e);

  }

}

JS

cat > pages/api/auth/logout.js <<'JS'

import { clearTokenCookie } from '../../../lib/auth';

import { handleSuccess } from '../../../utils/apiResponse';

export default function handler(req, res) {

  clearTokenCookie(res);

  return handleSuccess(res);

}

JS

echo "==> API: loans.js"

cat > pages/api/loans.js <<'JS'

import { supabaseServer } from '../../lib/supabaseServer';

import { getTokenFromReq, verifyToken } from '../../lib/auth';

import { handleError, handleSuccess } from '../../utils/apiResponse';

export default async function handler(req, res) {

  try {

    if (req.method === 'GET') {

      const id = req.query.id ? Number(req.query.id) : null;

      if (id) {

        const { data, error } = await supabaseServer.from('loans_vamto').select('*').eq('id', id).maybeSingle();

        if (error) return handleError(res, error);

        if (!data) return res.status(404).json({ ok:false, error: 'not found' });

        const out = { ...data, amount: data.amount!=null? data.amount.toString(): data.amount, price: data.price!=null? data.price.toString(): data.price };

        return handleSuccess(res, { loan: out });

      } else {

        const { data, error } = await supabaseServer.from('loans_vamto').select('*').order('id', { ascending: false });

        if (error) return handleError(res, error);

        const out = (data||[]).map(l => ({ ...l, amount: l.amount!=null?l.amount.toString():l.amount, price: l.price!=null?l.price.toString():l.price }));

        return handleSuccess(res, { loans: out });

      }

    }

    const token = getTokenFromReq(req);

    const user = token ? verifyToken(token) : null;

    if (!user || user.role !== 'admin') return res.status(403).json({ ok:false, error: 'forbidden' });

    if (req.method === 'POST') {

      const { title, amount, installments, price, bank_logo, is_credit } = req.body;

      const payload = { title, amount: Number(amount), installments: Number(installments), price: Number(price), bank_logo, is_credit: !!is_credit };

      const { data, error } = await supabaseServer.from('loans_vamto').insert([payload]).select().single();

      if (error) return handleError(res, error);

      return handleSuccess(res, { loan: data });

    }

    if (req.method === 'DELETE') {

      const id = Number(req.query.id);

      if (!id) return res.status(400).json({ ok:false, error: 'missing id' });

      const { error } = await supabaseServer.from('loans_vamto').delete().eq('id', id);

      if (error) return handleError(res, error);

      return handleSuccess(res);

    }

    if (req.method === 'PUT') {

      const { id, ...payload } = req.body || {};

      if (!id) return res.status(400).json({ ok:false, error: 'missing id' });

      if (payload.amount) payload.amount = Number(payload.amount);

      if (payload.installments) payload.installments = Number(payload.installments);

      if (payload.price) payload.price = Number(payload.price);

      const { error } = await supabaseServer.from('loans_vamto').update(payload).eq('id', Number(id));

      if (error) return handleError(res, error);

      return handleSuccess(res);

    }

    return res.status(405).json({ ok:false, error:'Method not allowed' });

  } catch (e) {

    return handleError(res, e);

  }

}

JS

echo "==> API: reservations.js"

cat > pages/api/reservations.js <<'JS'

import { supabaseServer } from '../../lib/supabaseServer';

import { getTokenFromReq, verifyToken } from '../../lib/auth';

import { handleError, handleSuccess } from '../../utils/apiResponse';

export default async function handler(req, res) {

  try {

    const token = getTokenFromReq(req);

    const user = token ? verifyToken(token) : null;

    if (req.method === 'POST') {

      if (!user) return res.status(401).json({ ok:false, error:'login_required' });

      const { loanId, fullname, phone } = req.body;

      if (!fullname || !phone || !loanId) return res.status(400).json({ ok:false, error:'missing' });

      if (phone !== user.phone) return res.status(403).json({ ok:false, error:'phone_mismatch' });

      const { data, error } = await supabaseServer.from('reservations').insert([{ user_id: Number(user.id), loan_id: Number(loanId), fullname, phone }]).select().single();

      if (error) return handleError(res, error);

      return handleSuccess(res, { reservation: data });

    }

    if (req.method === 'GET') {

      if (!user || user.role !== 'admin') return res.status(403).json({ ok:false, error:'forbidden' });

      const { data, error } = await supabaseServer.from('reservations').select('*, loans_vamto(*)').order('created_at', { ascending: false });

      if (error) return handleError(res, error);

      const safe = (data || []).map(r => ({ ...r, loans_vamto: r.loans_vamto ? { ...r.loans_vamto, amount: r.loans_vamto.amount!=null? r.loans_vamto.amount.toString(): r.loans_vamto.amount, price: r.loans_vamto.price!=null? r.loans_vamto.price.toString(): r.loans_vamto.price } : null }));

      return handleSuccess(res, { reservations: safe });

    }

    if (req.method === 'PATCH') {

      if (!user || user.role !== 'admin') return res.status(403).json({ ok:false, error:'forbidden' });

      const { id, status } = req.body;

      if (!id || !status) return res.status(400).json({ ok:false, error:'missing' });

      const { error } = await supabaseServer.from('reservations').update({ status }).eq('id', Number(id));

      if (error) return handleError(res, error);

      return handleSuccess(res);

    }

    return res.status(405).json({ ok:false, error:'Method not allowed' });

  } catch (e) {

    return handleError(res, e);

  }

}

JS

echo "==> API: admin/bank-logos.js (upload + cleanup + delete from storage)"

cat > pages/api/admin/bank-logos.js <<'JS'

import formidable from 'formidable';

import fs from 'fs';

import { supabaseServer } from '../../../lib/supabaseServer';

import { getTokenFromReq, verifyToken } from '../../../lib/auth';

import { handleError, handleSuccess } from '../../../utils/apiResponse';

export const config = { api: { bodyParser: false } };

export default async function handler(req, res) {

  try {

    const token = getTokenFromReq(req);

    const user = token ? verifyToken(token) : null;

    if (!user || user.role !== 'admin') return res.status(403).json({ ok:false, error: 'forbidden' });

    if (req.method === 'POST') {

      const form = new formidable.IncomingForm();

      form.parse(req, async (err, fields, files) => {

        if (err) return handleError(res, err);

        const file = files?.file;

        const title = (fields?.title) || 'بدون نام';

        if (!file) return res.status(400).json({ ok:false, error: 'no file provided' });

        try {

          const buffer = fs.readFileSync(file.filepath);

          const filename = `${Date.now()}-${(file.originalFilename || file.newFilename)}`.replace(/\s+/g, '_');

          const { error: upErr } = await supabaseServer.storage

            .from('bank-logos')

            .upload(filename, buffer, { contentType: file.mimetype });

          try { fs.unlinkSync(file.filepath); } catch(e) { console.error('cleanup failed', e); }

          if (upErr) return handleError(res, upErr);

          const publicUrl = supabaseServer.storage.from('bank-logos').getPublicUrl(filename).data.publicUrl;

          const { data, error: insertErr } = await supabaseServer

            .from('bank_logos')

            .insert([{ title, image_url: publicUrl }])

            .select()

            .single();

          if (insertErr) return handleError(res, insertErr);

          return handleSuccess(res, { logo: data });

        } catch (e) {

          try { fs.unlinkSync(file.filepath); } catch(ex) {}

          return handleError(res, e);

        }

      });

      return;

    }

    if (req.method === 'GET') {

      const { data, error } = await supabaseServer.from('bank_logos').select('*').order('id', { ascending: false });

      if (error) return handleError(res, error);

      return handleSuccess(res, { logos: data });

    }

    if (req.method === 'DELETE') {

      const id = Number(req.query.id);

      if (!id) return res.status(400).json({ ok:false, error: 'missing id' });

      const { data: row, error: getErr } = await supabaseServer.from('bank_logos').select('*').eq('id', id).single();

      if (getErr || !row) return res.status(404).json({ ok:false, error: 'not found' });

      try {

        const url = row.image_url || '';

        const fileName = url.split('/').pop();

        if (fileName) {

          await supabaseServer.storage.from('bank-logos').remove([fileName]);

        }

      } catch (e) {

        console.error('storage remove error', e);

      }

      const { error: delErr } = await supabaseServer.from('bank_logos').delete().eq('id', id);

      if (delErr) return handleError(res, delErr);

      return handleSuccess(res);

    }

    return res.status(405).json({ ok:false, error: 'Method not allowed' });

  } catch (e) {

    return handleError(res, e);

  }

}

JS

echo "==> README.md"

cat > README.md <<'MD'

# Vamto - Production-ready (Supabase only)

## Quick start

1. Copy files.

2. Create `.env.local` from `.env.example` and fill your Supabase creds + JWT_SECRET.

3. In Supabase SQL Editor run: `sql/setup.sql`.

4. Create a Storage bucket named `bank-logos`.

5. `npm install`

6. `npm run dev`

Notes:

- Keep SUPABASE_SERVICE_ROLE_KEY secret.

- Create an admin user manually in `users_vamto` table and set role='admin'.

MD

echo "==> Done. Project created in ./vamto-production"

echo ""

echo "NEXT STEPS (important):"

echo "1) cd vamto-production"

echo "2) cp .env.example .env.local  && edit .env.local with your Supabase URL/keys and JWT_SECRET"

echo "3) In Supabase SQL Editor run: sql/setup.sql"

echo "4) Create a bucket named 'bank-logos' in Supabase Storage"

echo "5) npm install"

echo "6) npm run dev"

echo ""

echo "If you want, I can now:"

echo " - generate the exact .env.local template for you to fill"

echo " - show SQL commands to create an initial admin user"

echo " - create a ZIP of the project content (instruction)"

echo ""

echo "Which one do you want next? (pick one):"

echo "A) .env.local template"

echo "B) SQL to create admin user"

echo "C) Create ZIP instructions"

echo "D) All of the above"