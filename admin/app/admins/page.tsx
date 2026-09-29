import { AdminShell } from "@/components/layout/AdminShell";
import { AccessDenied } from "@/components/ui/AccessDenied";
import { AdminTable } from "@/components/ui/AdminTable";
import { adminData } from "@/lib/admin-data";

type AdminUser = Record<string, unknown>;

export default async function AdminUsersPage() {
  const result = await adminData<AdminUser[]>("users");
  return <AdminShell active="admins" title="المدراء" subtitle="عرض حسابات الإدارة دون تعديلها من هذه الصفحة.">
    {result.forbidden ? <AccessDenied /> : <section className="panel">
      <div className="panelHeader"><div><p className="eyebrow">ADMIN ACCESS</p><h2>حسابات الإدارة</h2></div></div>
      <AdminTable rows={result.data ?? []} columns={[
        { key: "username", label: "اسم المستخدم" },
        { key: "email", label: "البريد" },
        { key: "role", label: "الدور" },
        { key: "mfaRequired", label: "MFA إلزامي" },
        { key: "disabledAt", label: "تعطيل الحساب" },
        { key: "lastLoginAt", label: "آخر دخول" }
      ]} />
    </section>}
  </AdminShell>;
}
