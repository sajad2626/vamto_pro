
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

