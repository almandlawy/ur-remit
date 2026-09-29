"use client";
import { FormEvent, useState, useTransition } from "react";
import { useRouter } from "next/navigation";

export function RateEditor({ id, buy, sell, feeFixed, feePercent }: {
  id: string;
  buy: string | null;
  sell: string | null;
  feeFixed: string | null;
  feePercent?: string | null;
}) {
  const router = useRouter(); const [message, setMessage] = useState(""); const [pending, startTransition] = useTransition();
  async function save(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setMessage(""); const data = new FormData(event.currentTarget);
    try {
      const response = await fetch(`/api/rates/${id}`, { method: "PATCH", headers: { "content-type": "application/json" },
        body: JSON.stringify({
          buy: data.get("buy") || null,
          sell: data.get("sell") || null,
          feeFixed: data.get("feeFixed") || null,
          ...(feePercent !== undefined ? { feePercent: data.get("feePercent") || null } : {})
        }) });
      if (!response.ok) { setMessage(response.status === 403 ? "لا تملك صلاحية تعديل الأسعار." : "لم يُحفظ التعديل. تحقق من القيم."); return; }
      setMessage("تم حفظ نسخة سعر جديدة وتسجيلها في سجل التدقيق."); startTransition(() => router.refresh());
    } catch {
      setMessage("تعذّر الاتصال بالخدمة. حاول مجدداً.");
    }
  }
  return <form onSubmit={save} className="rateEditor">
    <label>شراء<input name="buy" inputMode="decimal" pattern="[0-9]+(\.[0-9]{1,8})?" defaultValue={buy ?? ""} /></label>
    <label>بيع<input name="sell" inputMode="decimal" pattern="[0-9]+(\.[0-9]{1,8})?" defaultValue={sell ?? ""} /></label>
    <label>العمولة لكل 10,000$<input name="feeFixed" inputMode="decimal" pattern="-?[0-9]+(\.[0-9]{1,8})?" defaultValue={feeFixed ?? ""} /></label>
    {feePercent !== undefined
      ? <label>العمولة النسبية (%)<input name="feePercent" inputMode="decimal" pattern="[0-9]+(\.[0-9]{1,6})?" defaultValue={feePercent ?? ""} /></label>
      : null}
    <button className="secondaryButton" disabled={pending}>{pending ? "جارٍ الحفظ…" : "حفظ نسخة جديدة"}</button>
    <span className="inlineMessage" aria-live="polite">{message}</span>
  </form>;
}
