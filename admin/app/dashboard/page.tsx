import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { backendRequest } from "@/lib/backend";
import { RateEditor } from "@/components/RateEditor";

type Metrics = { activeRoutes?: number; activeOffices?: number; verifiedAgents?: number; pushSubscribers?: number; lastRateUpdate?: string | null };
type Rate = { id: string; routeNameArabic: string; routeNameEnglish: string; sourceCurrency: string; destinationCurrency: string; buy: string | null; sell: string | null; sourceTimestamp: string };

export default async function DashboardPage() {
  const token = (await cookies()).get("ur_admin_session")?.value; if (!token) redirect("/login");
  const [dashboardResponse, ratesResponse] = await Promise.all([
    backendRequest("/api/v1/admin/dashboard", { headers: { authorization: `Bearer ${token}` } }),
    backendRequest("/api/v1/mobile/rates")
  ]);
  if (dashboardResponse.status === 401) redirect("/login");
  const metrics = dashboardResponse.ok ? (await dashboardResponse.json() as { data: Metrics }).data : {};
  const rates = ratesResponse.ok ? (await ratesResponse.json() as { data: Rate[] }).data : [];
  const cards = [["المسارات النشطة", metrics.activeRoutes ?? "—"], ["المكاتب المعتمدة", metrics.activeOffices ?? "—"],
    ["الوكلاء المعتمدون", metrics.verifiedAgents ?? "—"], ["مشتركو الإشعارات", metrics.pushSubscribers ?? "—"]];
  return <main className="dashboardShell">
    <header className="topbar"><div><p className="eyebrow">UR CONTROL CENTRE</p><h1>لوحة إدارة أور</h1></div><div className="systemBadge">● API متصل</div></header>
    <section className="metricGrid" aria-label="ملخص النظام">{cards.map(([label, value]) =>
      <article className="metricCard" key={label}><span>{label}</span><strong>{value}</strong></article>)}</section>
    <section className="panel"><div className="panelHeader"><div><p className="eyebrow">RATE CONTROL</p><h2>الأسعار النشطة</h2></div>
      <p className="muted">كل تعديل ينشئ نسخة جديدة وسجل تدقيق غير قابل للتجاوز.</p></div>
      {rates.length === 0 ? <div className="emptyState">لا توجد أسعار Production منشورة.</div> :
        <div className="rateList">{rates.map((rate) => <article className="rateRow" key={rate.id}>
          <div><h3>{rate.routeNameArabic}</h3><p>{rate.sourceCurrency} / {rate.destinationCurrency}</p></div>
          <RateEditor id={rate.id} buy={rate.buy} sell={rate.sell} />
        </article>)}</div>}
    </section>
  </main>;
}

