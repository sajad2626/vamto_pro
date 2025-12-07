
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

