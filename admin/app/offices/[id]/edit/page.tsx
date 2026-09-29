import { notFound } from "next/navigation";
import { AdminShell } from "@/components/layout/AdminShell";
import { AccessDenied } from "@/components/ui/AccessDenied";
import { OfficeForm } from "@/components/offices/OfficeForm";
import { adminData } from "@/lib/admin-data";
import { adminLocations } from "@/lib/locations";

type Office = {
  id: string;
  countryId: string;
  cityId: string;
  publicCode: string;
  nameArabic: string;
  nameEnglish: string;
  addressArabic: string;
  addressEnglish: string;
  phone: string | null;
  whatsapp: string | null;
  latitude: string | null;
  longitude: string | null;
};

export default async function EditOfficePage({ params }: { params: Promise<{ id: string }> }) {
  const [{ id }, offices, locations] = await Promise.all([
    params,
    adminData<Office[]>("offices"),
    adminLocations()
  ]);
  if (offices.forbidden) {
    return <AdminShell active="offices" title="تعديل مكتب" subtitle="تحديث بيانات المكتب."><AccessDenied /></AdminShell>;
  }
  const office = offices.data?.find((item) => item.id === id);
  if (!office) notFound();
  return <AdminShell active="offices" title="تعديل مكتب" subtitle={`تحديث بيانات ${office.nameArabic}.`}>
    <OfficeForm initial={office} countries={locations.countries} cities={locations.cities} />
  </AdminShell>;
}
