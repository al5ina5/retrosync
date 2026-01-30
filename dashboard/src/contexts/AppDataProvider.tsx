"use client";

import { AuthProvider } from "./AuthContext";
import { DevicesProvider } from "./DevicesContext";
import { SavesProvider } from "./SavesContext";

export function AppDataProvider({ children }: { children: React.ReactNode }) {
  return (
    <AuthProvider>
      <DevicesProvider>
        <SavesProvider>{children}</SavesProvider>
      </DevicesProvider>
    </AuthProvider>
  );
}
