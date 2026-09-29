"use client";
import { FormEvent, useState, useTransition } from "react";
import { useRouter } from "next/navigation";

export default function LoginPage() {
  const router = useRouter(); const [error, setError] = useState(""); const [pending, startTransition] = useTransition();
  const [mode, setMode] = useState<"login" | "recover">("login");
  const [recoverMessage, setRecoverMessage] = useState("");

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

  async function submitRecover(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setError(""); setRecoverMessage(""); const data = new FormData(event.currentTarget);
    const response = await fetch("/api/session/recover", { method: "POST", headers: { "content-type": "application/json" },
      body: JSON.stringify({ email: data.get("email") }) });
    if (response.status === 503) {
      setError("تعذر الوصول إلى Supabase حالياً. حاول لاحقاً أو تواصل مع فريق التقنية.");
      return;
    }
    if (!response.ok) { setError("تعذر إرسال رابط إعادة التعيين. تحقق من صحة البريد."); return; }
    // Intentionally the same message whether the account exists or not — avoids revealing which
    // emails are registered admins.
    setRecoverMessage("إذا كان هذا البريد مرتبطاً بحساب إداري، فستصلك رسالة لإعادة تعيين كلمة المرور خلال دقائق.");
  }

  return <main className="loginShell">
    <section className="loginCard" aria-labelledby="login-title">
      <div className="brandMark" aria-hidden="true">UR</div><p className="eyebrow">بوابة الإدارة الآمنة</p>
      <h1 id="login-title">إدارة عمليات أور</h1>
      <p className="muted">{mode === "login" ? "دخول للمستخدمين المخولين." : "أدخل بريدك الإداري لإعادة تعيين كلمة المرور."}</p>
      {mode === "login" ? (
        <form onSubmit={submit} className="formStack">
          <label>البريد الإداري<input name="email" type="email" autoComplete="username" required /></label>
          <label>كلمة المرور<input name="password" type="password" autoComplete="current-password" required /></label>
          {error ? <p className="error" role="alert">{error}</p> : null}
          <button className="primaryButton" disabled={pending}>{pending ? "جارٍ الدخول…" : "دخول آمن"}</button>
          <button type="button" className="linkButton" onClick={() => { setMode("recover"); setError(""); }}>
            نسيت كلمة المرور؟
          </button>
        </form>
      ) : (
        <form onSubmit={submitRecover} className="formStack">
          <label>البريد الإداري<input name="email" type="email" autoComplete="username" required /></label>
          {error ? <p className="error" role="alert">{error}</p> : null}
          {recoverMessage ? <p className="inlineMessage" role="status" aria-live="polite">{recoverMessage}</p> : null}
          <button className="primaryButton" disabled={pending}>إرسال رابط إعادة التعيين</button>
          <button type="button" className="linkButton" onClick={() => { setMode("login"); setError(""); setRecoverMessage(""); }}>
            العودة لتسجيل الدخول
          </button>
        </form>
      )}
    </section>
  </main>;
}
