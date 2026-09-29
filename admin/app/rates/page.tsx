import { AdminShell } from "@/components/layout/AdminShell";
import { AccessDenied } from "@/components/ui/AccessDenied";
import { RateEditor } from "@/components/RateEditor";
import { adminData } from "@/lib/admin-data";

type Rate = {
  id: string;
  routeNameArabic: string;
  routeNameEnglish: string;
  sourceCurrency: string;
  destinationCurrency: string;
  buy: string | null;
  sell: string | null;
  feeFixed: string | null;
  feePercent: string | null;
  sourceTimestamp: string;
  version: number;
  active: boolean;
};

export default async function RatesPage() {
  const result = await adminData<Rate[]>("rates");
  return <AdminShell active="rates" title="أسعار الصرف" subtitle="إدارة الأسعار النشطة والإصدارات السابقة.">
    {result.forbidden ? <AccessDenied /> : <section className="panel">
      <div className="panelHeader"><div><p className="eyebrow">RATE CONTROL</p><h2>المسارات والأسعار</h2></div></div>
      {(result.data ?? []).length === 0
        ? <div className="emptyState">لا توجد أسعار.</div>
        : <div className="rateList">{result.data!.map((rate) =>
          <article className="rateRow" key={rate.id}>
            <div className="rateIdentity">
              <span className="currencyPair">{rate.sourceCurrency}<b>/</b>{rate.destinationCurrency}</span>
              <div><h3>{rate.routeNameArabic}</h3><p>{rate.routeNameEnglish} · الإصدار {rate.version} · {rate.active ? "نشط" : "سابق"}</p>
              <a className="textLink" href={`/rates/${rate.id}/edit`}>تفاصيل السعر</a></div>
            </div>
            {rate.active
              ? <RateEditor id={rate.id} buy={rate.buy} sell={rate.sell} feeFixed={rate.feeFixed} feePercent={rate.feePercent} />
              : <span className="muted">قراءة فقط · {new Date(rate.sourceTimestamp).toLocaleString("ar-IQ")}</span>}
          </article>
        )}</div>
      }
    </section>}
  </AdminShell>;
}
