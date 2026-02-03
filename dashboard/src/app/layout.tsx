import type { Metadata } from "next";
import "./globals.css";
import { AppDataProvider } from "@/contexts";
import { AppNav } from "@/components/AppNav";
import AppWrapper from "@/components/ui/AppWrapper";

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
          <AppWrapper>
            {/* <AppWrapper disabled={true}> */}
            <AppNav />
            {children}
          </AppWrapper>
        </AppDataProvider>
      </body>
    </html >
  );
}
