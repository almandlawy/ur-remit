import { AdminShell } from "@/components/layout/AdminShell";
import { AccessDenied } from "@/components/ui/AccessDenied";
import { RateEditor } from "@/components/RateEditor";
import { adminData } from "@/lib/admin-data";

type Metrics = {
  activeRoutes?: number;
  activeOffices?: number;
  verifiedAgents?: number;
  pushSubscribers?: number;
  lastRateUpdate?: string | null;
};
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
  active: boolean;
};

export default async function DashboardPage() {
  const [metricsResult, ratesResult] = await Promise.all([
    adminData<Metrics>("dashboard"),
    adminData<Rate[]>("rates")
  ]);
  if (metricsResult.forbidden) {
    return <AdminShell active="dashboard" title="لوحة إدارة أور" subtitle="ملخص العمليات الإدارية."><AccessDenied /></AdminShell>;
  }

  const metrics = metricsResult.data ?? {};
  const rates = (ratesResult.data ?? []).filter((rate) => rate.active);
  const usdIqd = rates.find((rate) => rate.sourceCurrency === "USD" && rate.destinationCurrency === "IQD");
  const cards = [
    ["المسارات النشطة", metrics.activeRoutes ?? "—"],
    ["المكاتب المعتمدة", metrics.activeOffices ?? "—"],
    ["الوكلاء المعتمدون", metrics.verifiedAgents ?? "—"],
    ["مشتركو الإشعارات", metrics.pushSubscribers ?? "—"]
  ];

  return <AdminShell active="dashboard" title="لوحة إدارة أور" subtitle="الأسعار والمكاتب والخدمات من مصدر واحد.">
    <section id="overview" className="heroMetrics" aria-label="السعر الرئيسي">
      <div>
        <p className="eyebrow">USD / IQD</p>
        <h2>السعر الرئيسي</h2>
        <p className="muted">آخر تحديث {metrics.lastRateUpdate ? new Date(metrics.lastRateUpdate).toLocaleString("ar-IQ") : "غير متوفر"}</p>
      </div>
      <div className="heroRate">
        <span>شراء<strong>{usdIqd?.buy ?? "—"}</strong></span>
        <span>بيع<strong>{usdIqd?.sell ?? "—"}</strong></span>
      </div>
    </section>
    <section className="metricGrid" aria-label="ملخص النظام">
      {cards.map(([label, value]) =>
        <article className="metricCard" key={label}><span>{label}</span><strong>{value}</strong></article>
      )}
    </section>
    <section className="panel">
      <div className="panelHeader">
        <div><p className="eyebrow">RATE CONTROL</p><h2>إدارة الأسعار</h2></div>
        <p className="muted">تعديل السعر ينشئ نسخة جديدة ويضيف سجلاً في سجل التدقيق.</p>
      </div>
      {ratesResult.forbidden
        ? <div className="emptyState"><strong>لا تملك صلاحية قراءة الأسعار</strong></div>
        : rates.length === 0
          ? <div className="emptyState"><strong>لا توجد أسعار منشورة</strong></div>
          : <div className="rateList">{rates.map((rate) =>
            <article className="rateRow" key={rate.id}>
              <div className="rateIdentity">
                <span className="currencyPair">{rate.sourceCurrency}<b>/</b>{rate.destinationCurrency}</span>
                <div><h3>{rate.routeNameArabic}</h3><p>{rate.routeNameEnglish}</p></div>
              </div>
              <RateEditor id={rate.id} buy={rate.buy} sell={rate.sell} feeFixed={rate.feeFixed} feePercent={rate.feePercent} />
            </article>
          )}</div>
      }
    </section>
  </AdminShell>;
}
