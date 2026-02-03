"use client";

import { useCallback, useState } from "react";

export interface UseUpgradeCheckoutOptions {
  getToken: () => string | null;
}

export interface UseUpgradeCheckoutReturn {
  startCheckout: () => Promise<boolean>;
  isLoading: boolean;
  error: string | null;
  clearError: () => void;
}

export function useUpgradeCheckout({
  getToken,
}: UseUpgradeCheckoutOptions): UseUpgradeCheckoutReturn {
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const clearError = useCallback(() => setError(null), []);

  const startCheckout = useCallback(async () => {
    setError(null);
    setIsLoading(true);
    const token = getToken();
    if (!token) {
      setError("Not signed in.");
      setIsLoading(false);
      return false;
    }
    try {
      const res = await fetch("/api/upgrade/checkout", {
        method: "POST",
        headers: { Authorization: `Bearer ${token}` },
      });
      const json = await res.json();
      if (!res.ok) {
        setError(json.error ?? "Checkout failed");
        return false;
      }
      if (json.data?.url) {
        window.location.href = json.data.url;
        return true;
      }
      setError("No checkout URL returned");
      return false;
    } catch {
      setError("Network error");
      return false;
    } finally {
      setIsLoading(false);
    }
  }, [getToken]);

  return { startCheckout, isLoading, error, clearError };
}
