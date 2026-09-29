import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { ADMIN_ACCESS_COOKIE, supabaseRestRequest } from "@/lib/supabase";
import { RatesPanel } from "@/components/RatesPanel";

type ActivityEntry = { action: string; entityType: string; entityId: string | null; createdAt: string; actorEmail: string | null };
type Metrics = { activeRoutes?: number; activeOffices?: number; verifiedAgents?: number; pushSubscribers?: number; lastRateUpdate?: string | null };
type Rate = { id: string; routeNameArabic: string; routeNameEnglish: string; sourceCurrency: string; destinationCurrency: string; buy: string | null; sell: string | null; feeFixed: string | null; sourceTimestamp: string };

type RateRow = {
  id: string; buy: string | null; sell: string | null; fee_fixed: string | null; source_timestamp: string;
  rate_routes: { name_ar: string; name_en: string; source_currency: string; destination_currency: string } | null;
};
type ActivityRow = { action: string; entity_type: string; entity_id: string | null; created_at: string; actor_email: string | null };

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
  const accessToken = (await cookies()).get(ADMIN_ACCESS_COOKIE)?.value;
  if (!accessToken) redirect("/login");

  const [metricsResponse, activityResponse, ratesResponse] = await Promise.all([
    supabaseRestRequest("rpc/admin_dashboard_metrics", { method: "POST", accessToken, body: "{}" }),
    supabaseRestRequest("rpc/admin_recent_activity", { method: "POST", accessToken, body: JSON.stringify({ limit_count: 10 }) }),
    supabaseRestRequest(
      "rates?select=id,buy,sell,fee_fixed,source_timestamp,rate_routes(name_ar,name_en,source_currency,destination_currency)&is_active=eq.true&order=source_timestamp.desc",
      { accessToken }
    ),
  ]);
  if (metricsResponse.status === 401 || ratesResponse.status === 401) redirect("/login");

  const metrics: Metrics = metricsResponse.ok ? await metricsResponse.json() : {};
  const activityRows: ActivityRow[] = activityResponse.ok ? await activityResponse.json() : [];
  const rateRows: RateRow[] = ratesResponse.ok ? await ratesResponse.json() : [];

  const rates: Rate[] = rateRows.map((row) => ({
    id: row.id,
    routeNameArabic: row.rate_routes?.name_ar ?? "—",
    routeNameEnglish: row.rate_routes?.name_en ?? "—",
    sourceCurrency: row.rate_routes?.source_currency ?? "—",
    destinationCurrency: row.rate_routes?.destination_currency ?? "—",
    buy: row.buy, sell: row.sell, feeFixed: row.fee_fixed, sourceTimestamp: row.source_timestamp,
  }));
  const activity: ActivityEntry[] = activityRows.map((row) => ({
    action: row.action, entityType: row.entity_type, entityId: row.entity_id, createdAt: row.created_at, actorEmail: row.actor_email,
  }));

  const usdIqd = rates.find((rate) => rate.sourceCurrency === "USD" && rate.destinationCurrency === "IQD");
  const cards = [["المسارات النشطة", metrics.activeRoutes ?? "—"], ["المكاتب المعتمدة", metrics.activeOffices ?? "—"],
    ["الوكلاء المعتمدون", metrics.verifiedAgents ?? "—"], ["مشتركو الإشعارات", metrics.pushSubscribers ?? "—"]];
  const health = rateHealth(metrics.lastRateUpdate);

  return <main className="adminFrame">
    <aside className="adminSidebar" aria-label="التنقل الإداري">
      <div className="adminBrand"><span className="brandMonogram">UR</span><div><strong>أور</strong><small>مركز التحكم</small></div></div>
      <nav><a className="active" href="#overview"><span aria-hidden="true">⌂</span>نظرة عامة</a>
        <a href="#rates"><span aria-hidden="true">↗</span>إدارة الأسعار</a>
        <a href="#activity"><span aria-hidden="true">◷</span>النشاط والصحة</a></nav>
      <div className="sidebarNotice"><strong>بيئة الإدارة</strong><span>كل تعديل موثق ومحمي بالصلاحيات، ومتصل مباشرة بقاعدة بيانات الإنتاج.</span></div>
    </aside>
    <div className="adminContent">
      <header className="topbar"><div><p className="eyebrow">UR CONTROL CENTRE</p><h1>لوحة إدارة أور</h1><p className="muted">الأسعار والمكاتب والخدمات من مصدر واحد.</p></div>
        <div className="badgeGroup"><span className="systemBadge"><span aria-hidden="true">●</span> متصل بـ Supabase</span>
          <span className={`healthBadge health-${health.tone}`}><span aria-hidden="true">●</span> {health.label}</span></div></header>
      <section id="overview" className="heroMetrics" aria-label="السعر الرئيسي">
        <div><p className="eyebrow">USD / IQD</p><h2>السعر الرئيسي</h2><p className="muted">آخر تحديث {metrics.lastRateUpdate ? new Date(metrics.lastRateUpdate).toLocaleString("ar-IQ") : "غير متوفر"}</p></div>
        <div className="heroRate"><span>شراء<strong>{usdIqd?.buy ?? "—"}</strong></span><span>بيع<strong>{usdIqd?.sell ?? "—"}</strong></span></div>
      </section>
      <section id="rates" className="panel"><div className="panelHeader"><div><p className="eyebrow">RATE CONTROL</p><h2>إدارة الأسعار</h2></div>
        <p className="muted">عدّل الشراء والبيع ثم احفظ. يُحدَّث السعر فوراً في قاعدة البيانات ويصل للتطبيق تلقائياً عبر Realtime، ويُسجَّل تلقائياً في سجل التدقيق.</p></div>
        <RatesPanel rates={rates} />
      </section>
      <section className="metricGrid" aria-label="ملخص النظام">{cards.map(([label, value]) =>
        <article className="metricCard" key={label}><span>{label}</span><strong>{value}</strong></article>)}</section>
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
