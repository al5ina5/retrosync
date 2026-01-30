"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import type { AuthState } from "@/types";
import type { UseAuthOptions, UseAuthReturn } from "./useAuth";

export function useAuthState(options: UseAuthOptions = {}): UseAuthReturn {
  const { redirectOnUnauthenticated = true, redirectTo = "/auth" } = options;
  const router = useRouter();
  const [state, setState] = useState<AuthState>({
    isAuthenticated: false,
    isLoading: true,
    token: null,
  });

  useEffect(() => {
    const token = localStorage.getItem("token");
    if (token) {
      setState({ isAuthenticated: true, isLoading: false, token });
    } else {
      setState({ isAuthenticated: false, isLoading: false, token: null });
      if (redirectOnUnauthenticated) router.push(redirectTo);
    }
  }, [router, redirectOnUnauthenticated, redirectTo]);

  const logout = useCallback(() => {
    localStorage.removeItem("token");
    localStorage.removeItem("user");
    setState({ isAuthenticated: false, isLoading: false, token: null });
    router.push("/");
  }, [router]);

  const getToken = useCallback(() => localStorage.getItem("token"), []);

  const login = useCallback(async (email: string, password: string) => {
    try {
      const res = await fetch("/api/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password }),
      });
      const data = await res.json();
      if (data.success && data.data?.token) {
        localStorage.setItem("token", data.data.token);
        setState({ isAuthenticated: true, isLoading: false, token: data.data.token });
        return { success: true };
      }
      return { success: false, error: data.error || "Login failed" };
    } catch {
      return { success: false, error: "Login failed" };
    }
  }, []);

  const register = useCallback(async (email: string, password: string) => {
    try {
      const res = await fetch("/api/auth/register", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password }),
      });
      const data = await res.json();
      if (data.success && data.data?.token) {
        localStorage.setItem("token", data.data.token);
        setState({ isAuthenticated: true, isLoading: false, token: data.data.token });
        return { success: true };
      }
      return { success: false, error: data.error || "Registration failed" };
    } catch {
      return { success: false, error: "Registration failed" };
    }
  }, []);

  return { ...state, logout, getToken, login, register };
}
