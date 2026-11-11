import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "AMANAH | Unilevel Management",
  description: "A transparent platform for managing your AMANAH network, products, and performance."
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
