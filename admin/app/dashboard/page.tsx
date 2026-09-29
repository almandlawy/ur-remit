import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { backendRequest } from "@/lib/backend";
import { RateEditor } from "@/components/RateEditor";

type ActivityEntry = { action: string; entityType: string; entityId: string | null; createdAt: string; actorEmail: string | null };
type Metrics = { activeRoutes?: number; activeOffices?: number; verifiedAgents?: number; pushSubscribers?: number; lastRateUpdate?: string | null; recentActivity?: ActivityEntry[] };
type Rate = { id: string; routeNameArabic: string; routeNameEnglish: string; sourceCurrency: string; destinationCurrency: string; buy: string | null; sell: string | null; feeFixed: string | null; sourceTimestamp: string };

const ACTION_LABELS: Record<string, string> = { UPDATE: "تحديث سعر", INSERT: "إضافة", DELETE: "حذف" };

// عتبات افتراضية معقولة لعرض صحة تحديث الأسعار: لا يوجد معيار محدد مسبقاً في النظام.
function rateHealth(lastRateUpdate?: string | null): { label: string; tone: "good" | "warn" | "bad" } {
  if (!lastRateUpdate) return { label: "لا يوجد سجل تحديث", tone: "bad" };
  const minutesAgo = (Date.now() - new Date(lastRateUpdate).getTime()) / 60000;
  if (minutesAgo < 30) return { label: "محدث", tone: "good" };
  if (minutesAgo < 120) return { label: "بحاجة لمتابعة", tone: "warn" };
  return { label: "متأخر", tone: "bad" };
}

export default async function DashboardPage() {
  const token = (await cookies()).get("ur_admin_session")?.value; if (!token) redirect("/login");
  const [dashboardResponse, ratesResponse] = await Promise.all([
    backendRequest("/api/v1/admin/dashboard", { headers: { authorization: `Bearer ${token}` } }),
    backendRequest("/api/v1/mobile/rates")
  ]);
  if (dashboardResponse.status === 401) redirect("/login");
  const metrics = dashboardResponse.ok ? (await dashboardResponse.json() as { data: Metrics }).data : {};
  const rates = ratesResponse.ok ? (await ratesResponse.json() as { data: Rate[] }).data : [];
  const usdIqd = rates.find((rate) => rate.sourceCurrency === "USD" && rate.destinationCurrency === "IQD");
  const cards = [["المسارات النشطة", metrics.activeRoutes ?? "—"], ["المكاتب المعتمدة", metrics.activeOffices ?? "—"],
    ["الوكلاء المعتمدون", metrics.verifiedAgents ?? "—"], ["مشتركو الإشعارات", metrics.pushSubscribers ?? "—"]];
  const health = rateHealth(metrics.lastRateUpdate);
  const activity = metrics.recentActivity ?? [];
  return <main className="adminFrame">
    <aside className="adminSidebar" aria-label="التنقل الإداري">
      <div className="adminBrand"><span className="brandMonogram">UR</span><div><strong>أور</strong><small>مركز التحكم</small></div></div>
      <nav><a className="active" href="#overview"><span aria-hidden="true">⌂</span>نظرة عامة</a>
        <a href="#rates"><span aria-hidden="true">↗</span>إدارة الأسعار</a>
        <a href="#activity"><span aria-hidden="true">◷</span>النشاط والصحة</a></nav>
      <div className="sidebarNotice"><strong>بيئة الإدارة</strong><span>كل تعديل موثق ومحمي بالصلاحيات.</span></div>
    </aside>
    <div className="adminContent">
      <header className="topbar"><div><p className="eyebrow">UR CONTROL CENTRE</p><h1>لوحة إدارة أور</h1><p className="muted">الأسعار والمكاتب والخدمات من مصدر واحد.</p></div>
        <div className="badgeGroup"><span className="systemBadge"><span aria-hidden="true">●</span> API متصل</span>
          <span className={`healthBadge health-${health.tone}`}><span aria-hidden="true">●</span> {health.label}</span></div></header>
      <section id="overview" className="heroMetrics" aria-label="السعر الرئيسي">
        <div><p className="eyebrow">USD / IQD</p><h2>السعر الرئيسي</h2><p className="muted">آخر تحديث {metrics.lastRateUpdate ? new Date(metrics.lastRateUpdate).toLocaleString("ar-IQ") : "غير متوفر"}</p></div>
        <div className="heroRate"><span>شراء<strong>{usdIqd?.buy ?? "—"}</strong></span><span>بيع<strong>{usdIqd?.sell ?? "—"}</strong></span></div>
      </section>
      <section className="metricGrid" aria-label="ملخص النظام">{cards.map(([label, value]) =>
        <article className="metricCard" key={label}><span>{label}</span><strong>{value}</strong></article>)}</section>
      <section id="rates" className="panel"><div className="panelHeader"><div><p className="eyebrow">RATE CONTROL</p><h2>إدارة الأسعار</h2></div>
        <p className="muted">عدّل الشراء والبيع ثم احفظ. ينشئ النظام نسخة جديدة وسجل تدقيق تلقائياً.</p></div>
        {rates.length === 0 ? <div className="emptyState"><strong>لا توجد أسعار منشورة</strong><span>ستظهر المسارات هنا عند ربط قاعدة بيانات Production.</span></div> :
          <div className="rateList">{rates.map((rate) => <article className="rateRow" key={rate.id}>
            <div className="rateIdentity"><span className="currencyPair">{rate.sourceCurrency}<b>/</b>{rate.destinationCurrency}</span><div><h3>{rate.routeNameArabic}</h3><p>{rate.routeNameEnglish}</p></div></div>
            <RateEditor id={rate.id} buy={rate.buy} sell={rate.sell} feeFixed={rate.feeFixed} />
          </article>)}</div>}
      </section>
      <section id="activity" className="panel" aria-label="النشاط الأخير وحالة النظام">
        <div className="panelHeader"><div><p className="eyebrow">AUDIT TRAIL</p><h2>النشاط الأخير وحالة النظام</h2></div>
          <p className="muted">آخر العمليات المسجلة تلقائياً في سجل التدقيق.</p></div>
        {activity.length === 0 ? <div className="emptyState"><strong>لا يوجد نشاط بعد</strong><span>ستظهر عمليات تعديل الأسعار هنا فور حدوثها.</span></div> :
          <ul className="activityList">{activity.map((entry, index) => <li className="activityRow" key={`${entry.entityId ?? "n"}-${index}`}>
            <span className={`activityDot action-${entry.action.toLowerCase()}`} aria-hidden="true">●</span>
            <div className="activityBody">
              <strong>{ACTION_LABELS[entry.action] ?? entry.action} — {entry.entityType}</strong>
              <span className="muted">{entry.actorEmail ?? "نظام"} · {new Date(entry.createdAt).toLocaleString("ar-IQ")}</span>
            </div>
          </li>)}</ul>}
      </section>
    </div>
  </main>;
}
