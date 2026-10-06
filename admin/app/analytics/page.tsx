import {AdminShell} from "@/components/layout/AdminShell";
import AppAnalyticsPanel from "@/components/analytics/AppAnalyticsPanel";
export default function AnalyticsPage(){return <AdminShell active="analytics" title="مراقبة التطبيق" subtitle="UR Global · Product Analytics"><AppAnalyticsPanel endpoint="/api/app-analytics"/></AdminShell>;}
