"use client";
import { FormEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";

/**
 * Landing page for the Supabase password-recovery email link. Supabase
 * redirects here with `access_token`/`type=recovery` in the URL *fragment*
 * (after `#`), which browsers never send to any server automatically, so we
 * read it client-side and post it explicitly to /api/auth/reset-password.
 */
export default function ResetPasswordPage() {
  const router = useRouter();
  const [accessToken, setAccessToken] = useState<string | null>(null);
  const [status, setStatus] = useState<"checking" | "ready" | "invalid" | "done">("checking");
  const [error, setError] = useState("");
  const [pending, setPending] = useState(false);

  useEffect(() => {
    const hash = new URLSearchParams(window.location.hash.replace(/^#/, ""));
    const token = hash.get("access_token");
    const type = hash.get("type");
    if (token && type === "recovery") {
      setAccessToken(token);
      setStatus("ready");
      // Remove the token from the visible URL/history once captured.
      window.history.replaceState(null, "", window.location.pathname);
    } else {
      setStatus("invalid");
    }
  }, []);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setError("");
    const data = new FormData(event.currentTarget);
    const newPassword = String(data.get("newPassword") ?? "");
    const confirmPassword = String(data.get("confirmPassword") ?? "");
    if (newPassword.length < 8) { setError("يجب أن تتكوّن كلمة المرور من 8 أحرف على الأقل."); return; }
    if (newPassword !== confirmPassword) { setError("كلمتا المرور غير متطابقتين."); return; }

    setPending(true);
    try {
      const response = await fetch("/api/auth/reset-password", {
        method: "POST", headers: { "content-type": "application/json" },
        body: JSON.stringify({ accessToken, newPassword })
      });
      if (!response.ok) { setError("انتهت صلاحية الرابط أو لم يعد صالحاً. اطلب رابطاً جديداً."); setPending(false); return; }
      setStatus("done");
    } catch {
      setError("تعذّر الاتصال بالخدمة. حاول مجدداً.");
      setPending(false);
    }
  }

  return <main className="loginShell">
    <section className="loginCard" aria-labelledby="reset-title">
      <div className="brandMark" aria-hidden="true">UR</div><p className="eyebrow">بوابة الإدارة الآمنة</p>
      <h1 id="reset-title">تعيين كلمة مرور جديدة</h1>
      {status === "checking" ? <p className="muted">جارٍ التحقق من الرابط…</p> : null}
      {status === "invalid" ? (
        <>
          <p className="error" role="alert">هذا الرابط غير صالح أو منتهي. اطلب رابط استعادة جديد من صفحة الدخول.</p>
          <button className="secondaryButton" onClick={() => router.replace("/login")}>الرجوع لتسجيل الدخول</button>
        </>
      ) : null}
      {status === "ready" ? (
        <form onSubmit={submit} className="formStack">
          <label>كلمة المرور الجديدة<input name="newPassword" type="password" minLength={8} autoComplete="new-password" required /></label>
          <label>تأكيد كلمة المرور<input name="confirmPassword" type="password" minLength={8} autoComplete="new-password" required /></label>
          {error ? <p className="error" role="alert">{error}</p> : null}
          <button className="primaryButton" disabled={pending}>{pending ? "جارٍ الحفظ…" : "حفظ كلمة المرور"}</button>
        </form>
      ) : null}
      {status === "done" ? (
        <>
          <p className="muted">تم تعيين كلمة المرور بنجاح. يمكنك الآن تسجيل الدخول بها.</p>
          <button className="primaryButton" onClick={() => router.replace("/login")}>الذهاب لتسجيل الدخول</button>
        </>
      ) : null}
    </section>
  </main>;
}
