"use client";

import { useState, useCallback } from "react";

export interface UseStripePortalOptions {
  getToken: () => string | null;
}

export interface UseStripePortalReturn {
  openPortal: () => Promise<void>;
  isLoading: boolean;
}

export function useStripePortal({ getToken }: UseStripePortalOptions): UseStripePortalReturn {
  const [isLoading, setIsLoading] = useState(false);

  const openPortal = useCallback(async () => {
    const token = getToken();
    if (!token) return;
    setIsLoading(true);
    try {
      const res = await fetch("/api/upgrade/portal", {
        method: "POST",
        headers: { Authorization: `Bearer ${token}` },
      });
      const json = await res.json();
      if (json.success && json.data?.url) {
        window.open(json.data.url, "_blank", "noopener,noreferrer");
        return;
      }
    } finally {
      setIsLoading(false);
    }
  }, [getToken]);

  return { openPortal, isLoading };
}
