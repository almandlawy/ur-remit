export type PublicRate = {
  id: string; routeNameArabic: string; routeNameEnglish: string;
  sourceCurrency: string; destinationCurrency: string;
  buy: string | null; sell: string | null; feeFixed: string | null; feePercent: string | null;
  updatedAt: string; sourceTimestamp: string; version: number;
  validFrom: string; validUntil: string | null; staleAfter: string;
};

export type PublicOffice = {
  id: string; publicCode: string; nameArabic: string; nameEnglish: string;
  countryArabic: string; countryEnglish: string; cityArabic: string; cityEnglish: string;
  addressArabic: string; addressEnglish: string; latitude: string | null; longitude: string | null;
  phone: string | null; whatsapp: string | null; workingHours: unknown; services: unknown; verified: true;
};

export type AgentVerification = {
  tradeName: string; country: { ar: string; en: string }; city: { ar: string; en: string };
  status: "VERIFIED" | "SUSPENDED" | "EXPIRED";
};

export type TransferPublicStatus = {
  reference: string; origin: string; destination: string;
  status: "ISSUED" | "ASSIGNED" | "READY_FOR_PICKUP" | "COMPLETED" | "CANCELLED" | "REFUNDED" | "HELD";
  lastUpdate: string; estimatedCompletion: string | null;
};
