import { AdminShell } from "@/components/layout/AdminShell";
import { OfficeForm } from "@/components/offices/OfficeForm";
import { adminLocations } from "@/lib/locations";

export const dynamic = "force-dynamic";

export default async function NewOfficePage() {
  const { countries, cities } = await adminLocations();
  return <AdminShell active="offices" title="إضافة مكتب" subtitle="أدخل بيانات المكتب وموقعه.">
    <OfficeForm countries={countries} cities={cities} />
  </AdminShell>;
}
