import { AdminShell } from "@/components/layout/AdminShell";
import { AccessDenied } from "@/components/ui/AccessDenied";
import { AdminTable } from "@/components/ui/AdminTable";
import { adminData } from "@/lib/admin-data";

type Agent = Record<string, unknown>;

export default async function AgentsPage() {
  const result = await adminData<Agent[]>("agents");
  return <AdminShell active="agents" title="الوكلاء" subtitle="عرض حالة الوكلاء ومناطق عملهم.">
    {result.forbidden ? <AccessDenied /> : <section className="panel">
      <div className="panelHeader"><div><p className="eyebrow">AGENT DIRECTORY</p><h2>الوكلاء المسجلون</h2></div></div>
      <AdminTable rows={result.data ?? []} columns={[
        { key: "tradeName", label: "الاسم التجاري" },
        { key: "status", label: "الحالة" },
        { key: "cityArabic", label: "المدينة" },
        { key: "countryArabic", label: "الدولة" },
        { key: "expiresAt", label: "انتهاء الصلاحية" },
        { key: "createdAt", label: "تاريخ التسجيل" }
      ]} />
    </section>}
  </AdminShell>;
}
