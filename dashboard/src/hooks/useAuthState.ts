"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import type { AuthState, AuthUser } from "@/types";
import {
  getAccount,
  updateAccount as updateAccountApi,
  deleteAccount as deleteAccountApi,
  type UpdateAccountBody,
} from "@/lib/api/account";
import type { UseAuthOptions, UseAuthReturn } from "./useAuth";

function userFromAccountData(data: {
  subscriptionTier?: string;
  email?: string;
  name?: string;
  createdAt?: string;
}): AuthUser | null {
  if (data?.subscriptionTier) {
    return {
      subscriptionTier: data.subscriptionTier,
      email: data.email ?? undefined,
      name: data.name ?? undefined,
      createdAt: data.createdAt ?? undefined,
    };
  }
  return null;
}

export function useAuthState(options: UseAuthOptions = {}): UseAuthReturn {
  const { redirectOnUnauthenticated = true, redirectTo = "/auth" } = options;
  const router = useRouter();
  const [state, setState] = useState<AuthState>({
    isAuthenticated: false,
    isLoading: true,
    token: null,
    user: null,
  });

  const fetchUser = useCallback((token: string) => {
    getAccount(token).then((result) => {
      if (result.success && result.data) {
        setState((prev) => ({
          ...prev,
          user: userFromAccountData(result.data) ?? { subscriptionTier: "free" },
        }));
      } else {
        setState((prev) => ({ ...prev, user: { subscriptionTier: "free" } }));
      }
    }).catch(() => setState((prev) => ({ ...prev, user: { subscriptionTier: "free" } })));
  }, []);

  const updateAccount = useCallback(async (body: UpdateAccountBody) => {
    const token = state.token ?? localStorage.getItem("token");
    if (!token) return { success: false as const, error: "Not authenticated" };
    const result = await updateAccountApi(token, body);
    if (result.success) return { success: true as const };
    return { success: false as const, error: result.error };
  }, [state.token]);

  const deleteAccount = useCallback(async (password: string) => {
    const token = state.token ?? localStorage.getItem("token");
    if (!token) return { success: false as const, error: "Not authenticated" };
    const result = await deleteAccountApi(token, password);
    if (result.success) return { success: true as const };
    return { success: false as const, error: result.error };
  }, [state.token]);

  useEffect(() => {
    const token = localStorage.getItem("token");
    if (token) {
      setState({ isAuthenticated: true, isLoading: false, token, user: null });
      fetchUser(token);
    } else {
      setState({ isAuthenticated: false, isLoading: false, token: null, user: null });
      if (redirectOnUnauthenticated) router.push(redirectTo);
    }
  }, [router, redirectOnUnauthenticated, redirectTo, fetchUser]);

  const logout = useCallback(() => {
    localStorage.removeItem("token");
    localStorage.removeItem("user");
    setState({ isAuthenticated: false, isLoading: false, token: null, user: null });
    router.push("/");
  }, [router]);

  const getToken = useCallback(() => localStorage.getItem("token"), []);

  const refreshUser = useCallback(() => {
    const token = localStorage.getItem("token");
    if (token) fetchUser(token);
  }, [fetchUser]);

  const login = useCallback(async (email: string, password: string) => {
    try {
      const res = await fetch("/api/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password }),
      });
      const data = await res.json();
      if (data.success && data.data?.token) {
        const token = data.data.token;
        localStorage.setItem("token", token);
        const user = data.data.user
          ? userFromAccountData(data.data.user)
          : { subscriptionTier: "free" };
        setState({
          isAuthenticated: true,
          isLoading: false,
          token,
          user: user ?? { subscriptionTier: "free" },
        });
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
        const token = data.data.token;
        localStorage.setItem("token", token);
        const user = data.data.user
          ? userFromAccountData(data.data.user)
          : { subscriptionTier: "free" };
        setState({
          isAuthenticated: true,
          isLoading: false,
          token,
          user: user ?? { subscriptionTier: "free" },
        });
        return { success: true };
      }
      return { success: false, error: data.error || "Registration failed" };
    } catch {
      return { success: false, error: "Registration failed" };
    }
  }, []);

  return { ...state, logout, getToken, login, register, refreshUser, updateAccount, deleteAccount };
}
