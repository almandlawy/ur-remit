"use client";
import { FormEvent, useState, useTransition } from "react";
import { useRouter } from "next/navigation";

export default function LoginPage() {
  const router = useRouter(); const [error, setError] = useState(""); const [pending, startTransition] = useTransition();
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setError(""); const data = new FormData(event.currentTarget);
    try {
      const response = await fetch("/api/session", { method: "POST", headers: { "content-type": "application/json" },
        body: JSON.stringify({ email: data.get("email"), password: data.get("password") }) });
      if (!response.ok) { setError(response.status === 401 ? "البريد الإلكتروني أو كلمة المرور غير صحيحة." : "تعذّر تسجيل الدخول."); return; }
      startTransition(() => { router.replace("/dashboard"); router.refresh(); });
    } catch {
      setError("تعذّر الاتصال بالخدمة. حاول مجدداً.");
    }
  }
  return <main className="loginShell">
    <section className="loginCard" aria-labelledby="login-title">
      <div className="brandMark" aria-hidden="true">UR</div><p className="eyebrow">بوابة الإدارة الآمنة</p>
      <h1 id="login-title">إدارة عمليات أور</h1><p className="muted">غيّر أسعار الصرف وعمولة كل 10,000 دولار من مكان واحد.</p>
      <form onSubmit={submit} className="formStack">
        <label>البريد الإلكتروني<input name="email" type="email" autoComplete="username" required /></label>
        <label>كلمة المرور<input name="password" type="password" minLength={8} autoComplete="current-password" required /></label>
        {error ? <p className="error" role="alert">{error}</p> : null}
        <button className="primaryButton" disabled={pending}>{pending ? "جارٍ الدخول…" : "دخول آمن"}</button>
      </form>
    </section>
  </main>;
}
