import { AdminShell } from "@/components/layout/AdminShell";
import { AccessDenied } from "@/components/ui/AccessDenied";
import { OfficeActions } from "@/components/offices/OfficeActions";
import { adminData } from "@/lib/admin-data";

type Office = {
  id: string;
  publicCode: string;
  nameArabic: string;
  countryArabic: string;
  cityArabic: string;
  phone: string | null;
  verified: boolean;
  active: boolean;
};

export default async function OfficesPage() {
  const result = await adminData<Office[]>("offices");
  return <AdminShell active="offices" title="المكاتب" subtitle="إدارة مكاتب التحويل وحالة الاعتماد.">
    {result.forbidden ? <AccessDenied /> : <section className="panel">
      <div className="panelHeader">
        <div><p className="eyebrow">OFFICE DIRECTORY</p><h2>دليل المكاتب</h2></div>
        <a className="primaryButton buttonLink" href="/offices/new">إضافة مكتب</a>
      </div>
      {(result.data ?? []).length === 0 ? <div className="emptyState">لا توجد مكاتب مسجلة.</div> :
        <div className="adminTableWrap"><table className="adminTable">
          <thead><tr><th>الرمز</th><th>الاسم</th><th>المدينة / الدولة</th><th>الهاتف</th><th>الحالة</th><th>الإجراءات</th></tr></thead>
          <tbody>{result.data!.map((office) => <tr key={office.id}>
            <td><code>{office.publicCode}</code></td>
            <td>{office.nameArabic}</td>
            <td>{office.cityArabic} · {office.countryArabic}</td>
            <td>{office.phone ?? "—"}</td>
            <td>{office.active ? office.verified ? "معتمد ونشط" : "غير معتمد" : "متوقف"}</td>
            <td><OfficeActions id={office.id} active={office.active} /></td>
          </tr>)}</tbody>
        </table></div>
      }
    </section>}
  </AdminShell>;
}
