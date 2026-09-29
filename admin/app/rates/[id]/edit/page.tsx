import { notFound } from "next/navigation";
import { AdminShell } from "@/components/layout/AdminShell";
import { AccessDenied } from "@/components/ui/AccessDenied";
import { RateEditor } from "@/components/RateEditor";
import { adminData } from "@/lib/admin-data";

type Rate = {
  id: string;
  routeNameArabic: string;
  routeNameEnglish: string;
  sourceCurrency: string;
  destinationCurrency: string;
  buy: string | null;
  sell: string | null;
  feeFixed: string | null;
  feePercent: string | null;
  sourceTimestamp: string;
  validFrom: string;
  validUntil: string | null;
  version: number;
  active: boolean;
};

export default async function EditRatePage({ params }: { params: Promise<{ id: string }> }) {
  const [{ id }, result] = await Promise.all([params, adminData<Rate[]>("rates")]);
  if (result.forbidden) {
    return <AdminShell active="rates" title="تفاصيل السعر" subtitle="عرض بيانات إصدار السعر."><AccessDenied /></AdminShell>;
  }
  const rate = result.data?.find((item) => item.id === id);
  if (!rate) notFound();
  return <AdminShell active="rates" title="تفاصيل السعر" subtitle={`${rate.routeNameArabic} · ${rate.sourceCurrency}/${rate.destinationCurrency}`}>
    <section className="panel rateDetail">
      <dl className="detailGrid">
        <div><dt>الإصدار</dt><dd>{rate.version}</dd></div>
        <div><dt>الحالة</dt><dd>{rate.active ? "نشط" : "سابق — قراءة فقط"}</dd></div>
        <div><dt>الشراء</dt><dd>{rate.buy ?? "—"}</dd></div>
        <div><dt>البيع</dt><dd>{rate.sell ?? "—"}</dd></div>
        <div><dt>العمولة الثابتة</dt><dd>{rate.feeFixed ?? "—"}</dd></div>
        <div><dt>العمولة النسبية</dt><dd>{rate.feePercent ?? "—"}</dd></div>
        <div><dt>بداية الصلاحية</dt><dd>{new Date(rate.validFrom).toLocaleString("ar-IQ")}</dd></div>
        <div><dt>نهاية الصلاحية</dt><dd>{rate.validUntil ? new Date(rate.validUntil).toLocaleString("ar-IQ") : "مفتوحة"}</dd></div>
        <div><dt>وقت المصدر</dt><dd>{new Date(rate.sourceTimestamp).toLocaleString("ar-IQ")}</dd></div>
      </dl>
    </section>
    {rate.active ? <section className="panel rateEditPanel">
      <h2>تحديث السعر</h2>
      <RateEditor id={rate.id} buy={rate.buy} sell={rate.sell} feeFixed={rate.feeFixed} feePercent={rate.feePercent} />
    </section> : null}
  </AdminShell>;
}
