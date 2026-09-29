import { AdminShell } from "@/components/layout/AdminShell";
import { AccessDenied } from "@/components/ui/AccessDenied";
import { AdminTable } from "@/components/ui/AdminTable";
import { adminData } from "@/lib/admin-data";

type AuditEntry = Record<string, unknown>;

export default async function AuditPage() {
  const result = await adminData<AuditEntry[]>("audit");
  return <AdminShell active="audit" title="سجل التدقيق" subtitle="أحدث الإجراءات الإدارية المسجلة.">
    {result.forbidden ? <AccessDenied /> : <section className="panel">
      <div className="panelHeader"><div><p className="eyebrow">AUDIT TRAIL</p><h2>النشاط الأخير</h2></div></div>
      <AdminTable rows={result.data ?? []} columns={[
        { key: "createdAt", label: "التاريخ" },
        { key: "actor", label: "المدير" },
        { key: "action", label: "الإجراء" },
        { key: "entityType", label: "نوع السجل" },
        { key: "entityId", label: "معرّف السجل" },
        { key: "requestId", label: "معرّف الطلب" }
      ]} />
    </section>}
  </AdminShell>;
}
