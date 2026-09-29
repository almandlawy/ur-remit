"use client";
import { useMemo, useState } from "react";
import { RateEditor } from "@/components/RateEditor";

type Rate = { id: string; routeNameArabic: string; routeNameEnglish: string; sourceCurrency: string; destinationCurrency: string; buy: string | null; sell: string | null; feeFixed: string | null; sourceTimestamp: string };

// يعرض هذا المكوّن قائمة الأسعار مع بحث فوري بدون إعادة تحميل الصفحة، لتسريع تعديل السعر المطلوب بين عشرات المسارات.
export function RatesPanel({ rates }: { rates: Rate[] }) {
  const [query, setQuery] = useState("");
  const filtered = useMemo(() => {
    const needle = query.trim().toLowerCase();
    if (!needle) return rates;
    return rates.filter((rate) =>
      rate.routeNameArabic.toLowerCase().includes(needle) ||
      rate.routeNameEnglish.toLowerCase().includes(needle) ||
      rate.sourceCurrency.toLowerCase().includes(needle) ||
      rate.destinationCurrency.toLowerCase().includes(needle)
    );
  }, [query, rates]);

  return <>
    <div className="rateSearch">
      <label htmlFor="rate-search" className="visuallyHidden">بحث عن مسار أو عملة</label>
      <input
        id="rate-search"
        type="search"
        placeholder="ابحث بالعملة أو اسم المسار (مثال: IQD، تركيا)…"
        value={query}
        onChange={(event) => setQuery(event.target.value)}
        aria-describedby="rate-search-count"
      />
      <span id="rate-search-count" className="muted" aria-live="polite">
        {filtered.length === rates.length ? `${rates.length} مسار` : `${filtered.length} من أصل ${rates.length}`}
      </span>
    </div>
    {rates.length === 0 ? (
      <div className="emptyState"><strong>لا توجد أسعار منشورة</strong><span>ستظهر المسارات هنا عند ربط قاعدة بيانات Production.</span></div>
    ) : filtered.length === 0 ? (
      <div className="emptyState"><strong>لا نتائج مطابقة</strong><span>جرّب كلمة بحث أخرى أو امسح مربع البحث.</span></div>
    ) : (
      <div className="rateList">
        {filtered.map((rate) => (
          <article className="rateRow" key={rate.id}>
            <div className="rateIdentity">
              <span className="currencyPair">{rate.sourceCurrency}<b>/</b>{rate.destinationCurrency}</span>
              <div><h3>{rate.routeNameArabic}</h3><p>{rate.routeNameEnglish}</p></div>
            </div>
            <RateEditor id={rate.id} buy={rate.buy} sell={rate.sell} feeFixed={rate.feeFixed} />
          </article>
        ))}
      </div>
    )}
  </>;
}
