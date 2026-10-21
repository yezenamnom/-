import type { Metadata } from "next";
import "./globals.css";
import { S } from "@/lib/strings";

export const metadata: Metadata = {
  title: S.appName,
  robots: { index: false, follow: false },
};

// Every page is rendered per request (session-dependent + per-request CSP nonce).
export const dynamic = "force-dynamic";

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
