"use client";
import { FormEvent, useState, useTransition } from "react";
import { useRouter } from "next/navigation";

export default function LoginPage() {
  const router = useRouter(); const [error, setError] = useState(""); const [pending, startTransition] = useTransition();
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setError(""); const data = new FormData(event.currentTarget);
    const response = await fetch("/api/session", { method: "POST", headers: { "content-type": "application/json" },
      body: JSON.stringify({ email: data.get("email"), password: data.get("password") }) });
    if (response.status === 503) {
      setError("تعذر الوصول إلى Supabase حالياً. تحقّق من إعداد SUPABASE_URL و SUPABASE_PUBLISHABLE_KEY على الخادم، أو من اتصال الإنترنت.");
      return;
    }
    if (response.status === 403) { setError("هذا الحساب غير مُدرَج كمسؤول (admin) في قاعدة البيانات."); return; }
    if (response.status === 401) { setError("البريد أو كلمة المرور غير صحيحة."); return; }
    if (!response.ok) { setError("تعذر تسجيل الدخول. تأكد من صحة البيانات المدخلة."); return; }
    startTransition(() => { router.replace("/dashboard"); router.refresh(); });
  }
  return <main className="loginShell">
    <section className="loginCard" aria-labelledby="login-title">
      <div className="brandMark" aria-hidden="true">UR</div><p className="eyebrow">بوابة الإدارة الآمنة</p>
      <h1 id="login-title">إدارة عمليات أور</h1><p className="muted">دخول للمستخدمين المخولين.</p>
      <form onSubmit={submit} className="formStack">
        <label>البريد الإداري<input name="email" type="email" autoComplete="username" required /></label>
        <label>كلمة المرور<input name="password" type="password" autoComplete="current-password" required /></label>
        {error ? <p className="error" role="alert">{error}</p> : null}
        <button className="primaryButton" disabled={pending}>{pending ? "جارٍ الدخول…" : "دخول آمن"}</button>
      </form>
    </section>
  </main>;
}
