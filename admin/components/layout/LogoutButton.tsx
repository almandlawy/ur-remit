"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

export function LogoutButton() {
  const router = useRouter();
  const [error, setError] = useState("");

  async function logout() {
    setError("");
    try {
      const response = await fetch("/api/session", { method: "DELETE" });
      if (!response.ok) {
        setError("تعذّر إنهاء الجلسة.");
        return;
      }
      router.replace("/login");
      router.refresh();
    } catch {
      setError("تعذّر إنهاء الجلسة.");
    }
  }

  return <div className="logoutControl">
    <button className="secondaryButton" type="button" onClick={logout}>تسجيل الخروج</button>
    {error ? <span role="alert">{error}</span> : null}
  </div>;
}
