"use client";

import { FormEvent, useState } from "react";
import { useRouter } from "next/navigation";
import type { City, Country } from "@/lib/locations";

type OfficeValues = {
  id?: string;
  countryId?: string;
  cityId?: string;
  publicCode?: string;
  nameArabic?: string;
  nameEnglish?: string;
  addressArabic?: string;
  addressEnglish?: string;
  phone?: string | null;
  whatsapp?: string | null;
  latitude?: string | null;
  longitude?: string | null;
};

export function OfficeForm({ initial = {}, countries, cities }: {
  initial?: OfficeValues;
  countries: Country[];
  cities: City[];
}) {
  const router = useRouter();
  const [countryId, setCountryId] = useState(initial.countryId ?? "");
  const [cityId, setCityId] = useState(initial.cityId ?? "");
  const [error, setError] = useState("");
  const [pending, setPending] = useState(false);
  const countryCode = countries.find((country) => country.id === countryId)?.isoCode;
  const visibleCities = cities.filter((city) => city.countryCode === countryCode);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    setPending(true);
    const data = new FormData(event.currentTarget);
    const payload = {
      countryId,
      cityId,
      publicCode: data.get("publicCode"),
      nameArabic: data.get("nameArabic"),
      nameEnglish: data.get("nameEnglish"),
      addressArabic: data.get("addressArabic"),
      addressEnglish: data.get("addressEnglish"),
      phone: data.get("phone") || null,
      whatsapp: data.get("whatsapp") || null,
      latitude: data.get("latitude") || null,
      longitude: data.get("longitude") || null
    };
    try {
      const response = await fetch(initial.id ? `/api/admin/offices/${initial.id}` : "/api/admin/offices", {
        method: initial.id ? "PATCH" : "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(payload)
      });
      if (!response.ok) {
        setError(response.status === 403
          ? "حسابك لا يملك صلاحية إدارة المكاتب."
          : "تعذّر حفظ المكتب. تحقق من الحقول والموقع المختار.");
        return;
      }
      router.push("/offices");
      router.refresh();
    } catch {
      setError("تعذّر الاتصال بالخدمة. حاول مجدداً.");
    } finally {
      setPending(false);
    }
  }

  return <form onSubmit={submit} className="officeForm panel">
    <div className="officeFields">
      <label>رمز المكتب<input name="publicCode" required minLength={2} maxLength={32} defaultValue={initial.publicCode ?? ""} /></label>
      <label>الدولة<select value={countryId} onChange={(event) => { setCountryId(event.target.value); setCityId(""); }} required>
        <option value="">اختر الدولة</option>
        {countries.map((country) => <option value={country.id} key={country.id}>{country.nameArabic}</option>)}
      </select></label>
      <label>المدينة<select value={cityId} onChange={(event) => setCityId(event.target.value)} required disabled={!countryId}>
        <option value="">اختر المدينة</option>
        {visibleCities.map((city) => <option value={city.id} key={city.id}>{city.nameArabic}</option>)}
      </select></label>
      <label>الاسم بالعربية<input name="nameArabic" required maxLength={160} defaultValue={initial.nameArabic ?? ""} /></label>
      <label>الاسم بالإنجليزية<input name="nameEnglish" required maxLength={160} defaultValue={initial.nameEnglish ?? ""} /></label>
      <label>العنوان بالعربية<input name="addressArabic" required maxLength={500} defaultValue={initial.addressArabic ?? ""} /></label>
      <label>العنوان بالإنجليزية<input name="addressEnglish" required maxLength={500} defaultValue={initial.addressEnglish ?? ""} /></label>
      <label>الهاتف<input name="phone" maxLength={32} defaultValue={initial.phone ?? ""} /></label>
      <label>واتساب<input name="whatsapp" maxLength={32} defaultValue={initial.whatsapp ?? ""} /></label>
      <label>خط العرض<input name="latitude" inputMode="decimal" pattern="-?[0-9]{1,3}(\.[0-9]{1,6})?" defaultValue={initial.latitude ?? ""} /></label>
      <label>خط الطول<input name="longitude" inputMode="decimal" pattern="-?[0-9]{1,3}(\.[0-9]{1,6})?" defaultValue={initial.longitude ?? ""} /></label>
    </div>
    {error ? <p className="error" role="alert">{error}</p> : null}
    <div className="formActions">
      <button className="primaryButton" disabled={pending || !countryId || !cityId}>
        {pending ? "جارٍ الحفظ…" : initial.id ? "حفظ التغييرات" : "إنشاء المكتب"}
      </button>
      <a className="secondaryButton buttonLink" href="/offices">إلغاء</a>
    </div>
  </form>;
}
