"use client";
import { FormEvent, useState, useTransition } from "react";
import { useRouter } from "next/navigation";

export function RateEditor({ id, buy, sell }: { id: string; buy: string | null; sell: string | null }) {
  const router = useRouter(); const [message, setMessage] = useState(""); const [pending, startTransition] = useTransition();
  async function save(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setMessage(""); const data = new FormData(event.currentTarget);
    const response = await fetch(`/api/rates/${id}`, { method: "PATCH", headers: { "content-type": "application/json" },
      body: JSON.stringify({ buy: data.get("buy") || null, sell: data.get("sell") || null }) });
    if (!response.ok) { setMessage("لم يُحفظ التعديل. تحقق من الصلاحية والقيم."); return; }
    setMessage("تم حفظ نسخة سعر جديدة وتسجيلها في سجل التدقيق."); startTransition(() => router.refresh());
  }
  return <form onSubmit={save} className="rateEditor">
    <label>شراء<input name="buy" inputMode="decimal" pattern="[0-9]+(\.[0-9]{1,8})?" defaultValue={buy ?? ""} /></label>
    <label>بيع<input name="sell" inputMode="decimal" pattern="[0-9]+(\.[0-9]{1,8})?" defaultValue={sell ?? ""} /></label>
    <button className="secondaryButton" disabled={pending}>{pending ? "جارٍ الحفظ…" : "حفظ نسخة جديدة"}</button>
    <span className="inlineMessage" aria-live="polite">{message}</span>
  </form>;
}

