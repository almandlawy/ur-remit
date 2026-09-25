import type { Metadata } from "next";
import "./styles.css";

export const metadata: Metadata = { title: "UR Admin", robots: { index: false, follow: false } };

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="ar" dir="rtl"><body>{children}</body></html>;
}

