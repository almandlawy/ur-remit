"use client";

import { FormEvent, useState } from "react";
import { useRouter } from "next/navigation";

export function PasswordChangeForm() {
  const router = useRouter();
  const [error, setError] = useState("");
  const [pending, setPending] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    setPending(true);
    const form = new FormData(event.currentTarget);
    const newPassword = String(form.get("newPassword") ?? "");
    if (newPassword !== String(form.get("confirmPassword") ?? "")) {
      setError("كلمتا المرور الجديدتان غير متطابقتين.");
      setPending(false);
      return;
    }
    try {
      const response = await fetch("/api/admin/auth/change-password", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          currentPassword: form.get("currentPassword"),
          newPassword,
          mfaCode: form.get("mfaCode")
        })
      });
      if (!response.ok) {
        setError(response.status === 401
          ? "كلمة المرور الحالية أو رمز المصادقة غير صحيح."
          : "تعذّر تغيير كلمة المرور. تحقق من القيم المدخلة.");
        return;
      }
      router.replace("/login");
      router.refresh();
    } catch {
      setError("تعذّر الاتصال بالخدمة. حاول مجدداً.");
    } finally {
      setPending(false);
    }
  }

  return <form className="formStack panel passwordForm" onSubmit={submit}>
    <label>كلمة المرور الحالية<input type="password" name="currentPassword" autoComplete="current-password" required minLength={10} maxLength={256} /></label>
    <label>كلمة المرور الجديدة<input type="password" name="newPassword" autoComplete="new-password" required minLength={12} maxLength={256} /></label>
    <label>تأكيد كلمة المرور<input type="password" name="confirmPassword" autoComplete="new-password" required minLength={12} maxLength={256} /></label>
    <label>رمز المصادقة الثنائية<input name="mfaCode" inputMode="numeric" autoComplete="one-time-code" pattern="[0-9]{6}" required /></label>
    {error ? <p role="alert" className="error">{error}</p> : null}
    <button className="primaryButton" disabled={pending}>{pending ? "جارٍ التغيير…" : "تغيير كلمة المرور"}</button>
  </form>;
}
