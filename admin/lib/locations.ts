import "server-only";
import { backendRequest } from "@/lib/backend";

export type Country = { id: string; isoCode: string; nameArabic: string; nameEnglish: string };
export type City = { id: string; nameArabic: string; nameEnglish: string; countryCode: string };

export async function adminLocations() {
  const [countriesResponse, citiesResponse] = await Promise.all([
    backendRequest("/api/v1/mobile/countries"),
    backendRequest("/api/v1/mobile/cities")
  ]);
  if (!countriesResponse.ok || !citiesResponse.ok)
    throw new Error("Unable to load office locations");
  const countries = await countriesResponse.json() as { data: Country[] };
  const cities = await citiesResponse.json() as { data: City[] };
  return { countries: countries.data, cities: cities.data };
}
