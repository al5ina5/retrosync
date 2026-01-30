import type { Metadata } from "next";
import "./globals.css";
import { AppDataProvider } from "@/contexts";
import { AppNav } from "@/components/AppNav";

export const metadata: Metadata = {
  title: "RetroSync",
  description: "Sync your retro game saves",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>
        <AppDataProvider>
          <AppNav />
          {children}
        </AppDataProvider>
      </body>
    </html>
  );
}
