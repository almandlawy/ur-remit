import type { ReactNode } from "react";
import { LogoutButton } from "@/components/layout/LogoutButton";
import { adminData } from "@/lib/admin-data";

const navigation = [
  ["dashboard", "/dashboard", "نظرة عامة"],
  ["rates", "/rates", "أسعار الصرف"],
  ["offices", "/offices", "المكاتب"],
  ["agents", "/agents", "الوكلاء"],
  ["admins", "/admins", "المدراء"],
  ["audit", "/audit", "سجل التدقيق"],
  ["settings", "/settings", "الإعدادات"]
] as const;

export async function AdminShell({ active, title, subtitle, children }: {
  active: typeof navigation[number][0];
  title: string;
  subtitle: string;
  children: ReactNode;
}) {
  await adminData<{ id: string; role: string }>("me");
  return <main className="adminFrame">
    <aside className="adminSidebar" aria-label="التنقل الإداري">
      <div className="adminBrand">
        <span className="brandMonogram">UR</span>
        <div><strong>أور</strong><small>مركز التحكم</small></div>
      </div>
      <nav>
        {navigation.map(([key, href, label]) =>
          <a className={active === key ? "active" : ""} href={href} key={key}>{label}</a>
        )}
      </nav>
      <div className="sidebarNotice"><strong>بيئة الإدارة</strong><span>كل تعديل موثق ومحمي بالصلاحيات.</span></div>
    </aside>
    <div className="adminContent">
      <header className="topbar">
        <div><p className="eyebrow">UR CONTROL CENTRE</p><h1>{title}</h1><p className="muted">{subtitle}</p></div>
        <LogoutButton />
      </header>
      {children}
    </div>
  </main>;
}
