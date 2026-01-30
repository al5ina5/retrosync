"use client";

import type { AuthState } from "@/types";
import { useAuthContext } from "@/contexts/AuthContext";
import { useAuthState } from "./useAuthState";

export interface UseAuthOptions {
  redirectOnUnauthenticated?: boolean;
  redirectTo?: string;
}

export interface UseAuthReturn extends AuthState {
  logout: () => void;
  getToken: () => string | null;
  login: (email: string, password: string) => Promise<{ success: boolean; error?: string }>;
  register: (email: string, password: string) => Promise<{ success: boolean; error?: string }>;
}

export function useAuth(options: UseAuthOptions = {}): UseAuthReturn {
  const context = useAuthContext();
  const state = useAuthState(options);
  if (context != null) return context;
  return state;
}
