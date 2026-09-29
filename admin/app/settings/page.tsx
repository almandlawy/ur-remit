import { AdminShell } from "@/components/layout/AdminShell";
import { PasswordChangeForm } from "@/components/settings/PasswordChangeForm";
import { adminData } from "@/lib/admin-data";

export default async function SettingsPage() {
  await adminData<{ id: string; role: string }>("me");
  return <AdminShell active="settings" title="الإعدادات" subtitle="إعدادات أمان الحساب الإداري.">
    <section className="panel settingsIntro">
      <p>تغيير كلمة المرور يتطلب كلمة المرور الحالية ورمز MFA. بعد نجاح التغيير تُنهى جميع جلسات الحساب ويجب تسجيل الدخول مجدداً.</p>
    </section>
    <PasswordChangeForm />
  </AdminShell>;
}
