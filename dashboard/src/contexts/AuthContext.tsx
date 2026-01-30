"use client";

import { createContext, useContext } from "react";
import type { UseAuthReturn } from "@/hooks/useAuth";
import { useAuthState } from "@/hooks/useAuthState";

const AuthContext = createContext<UseAuthReturn | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const value = useAuthState({ redirectOnUnauthenticated: false });
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuthContext(): UseAuthReturn | null {
  return useContext(AuthContext);
}
