"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

export function OfficeActions({ id, active }: { id: string; active: boolean }) {
  const router = useRouter();
  const [error, setError] = useState("");
  const [pending, setPending] = useState(false);

  async function deactivate() {
    if (!window.confirm("هل تريد إيقاف هذا المكتب؟ سيبقى سجله محفوظاً.")) return;
    setPending(true);
    setError("");
    try {
      const response = await fetch(`/api/admin/offices/${id}`, { method: "DELETE" });
      if (!response.ok) {
        setError("تعذّر إيقاف المكتب.");
        return;
      }
      router.refresh();
    } catch {
      setError("تعذّر الاتصال بالخدمة.");
    } finally {
      setPending(false);
    }
  }

  return <div className="rowActions">
    <a className="secondaryButton buttonLink" href={`/offices/${id}/edit`}>تعديل</a>
    {active ? <button className="dangerButton" type="button" onClick={deactivate} disabled={pending}>
      {pending ? "جارٍ الإيقاف…" : "إيقاف"}
    </button> : <span className="muted">متوقف</span>}
    {error ? <span className="error" role="alert">{error}</span> : null}
  </div>;
}
