"use client";
import { FormEvent, useState, useTransition } from "react";
import { useRouter } from "next/navigation";

export default function LoginPage() {
  const router = useRouter(); const [error, setError] = useState(""); const [pending, startTransition] = useTransition();
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setError(""); const data = new FormData(event.currentTarget);
    const response = await fetch("/api/session", { method: "POST", headers: { "content-type": "application/json" },
      body: JSON.stringify({ email: data.get("email"), password: data.get("password"), otp: data.get("otp") }) });
    if (!response.ok) { setError("تعذر التحقق من بيانات الدخول. راجع البيانات ورمز المصادقة."); return; }
    startTransition(() => { router.replace("/dashboard"); router.refresh(); });
  }
  return <main className="loginShell">
    <section className="loginCard" aria-labelledby="login-title">
      <div className="brandMark" aria-hidden="true">UR</div><p className="eyebrow">بوابة الإدارة الآمنة</p>
      <h1 id="login-title">إدارة عمليات أور</h1><p className="muted">الدخول مخصص للمستخدمين المخولين ويتطلب رمز المصادقة الثنائية.</p>
      <form onSubmit={submit} className="formStack">
        <label>البريد الإداري<input name="email" type="email" autoComplete="username" required /></label>
        <label>كلمة المرور<input name="password" type="password" minLength={12} autoComplete="current-password" required /></label>
        <label>رمز المصادقة<input name="otp" inputMode="numeric" pattern="[0-9]{6}" maxLength={6} autoComplete="one-time-code" required /></label>
        {error ? <p className="error" role="alert">{error}</p> : null}
        <button className="primaryButton" disabled={pending}>{pending ? "جارٍ الدخول…" : "دخول آمن"}</button>
      </form>
    </section>
  </main>;
}

