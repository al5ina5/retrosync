"use client";

import { useState, useCallback } from "react";
import useSWR, { mutate } from "swr";
import { fetcher } from "@/lib/fetcher";
import type { DevicesResponse } from "@/types";
import type { UseDevicesOptions, UseDevicesReturn } from "./useDevices";

export function useDevicesState(options: UseDevicesOptions = {}): UseDevicesReturn {
  const { refreshInterval = 0, onPairingSuccess, onDeleteSuccess } = options;
  const [isPairing, setIsPairing] = useState(false);
  const [pairingError, setPairingError] = useState<string | null>(null);
  const [pairingSuccess, setPairingSuccess] = useState(false);
  const [isDeleting, setIsDeleting] = useState<string | null>(null);
  const [deleteError, setDeleteError] = useState<string | null>(null);

  const { data, error, isLoading, isValidating } = useSWR<DevicesResponse>(
    typeof window !== "undefined" && localStorage.getItem("token") ? "/api/devices" : null,
    fetcher,
    { refreshInterval: pairingSuccess ? 2000 : refreshInterval }
  );

  const devices = data?.devices || [];

  const refresh = useCallback(async () => {
    await mutate("/api/devices");
  }, []);

  const pairDevice = useCallback(
    async (code: string): Promise<boolean> => {
      if (code.length !== 6) {
        setPairingError("Code must be 6 characters");
        return false;
      }
      setIsPairing(true);
      setPairingError(null);
      setPairingSuccess(false);
      try {
        const token = localStorage.getItem("token");
        const response = await fetch("/api/devices/pair", {
          method: "POST",
          headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
          body: JSON.stringify({ code }),
        });
        const data = await response.json();
        if (data.success) {
          setPairingSuccess(true);
          onPairingSuccess?.();
          setTimeout(() => setPairingSuccess(false), 30000);
          return true;
        }
        setPairingError(data.error || "Failed to link code");
        return false;
      } catch {
        setPairingError("Failed to link code");
        return false;
      } finally {
        setIsPairing(false);
      }
    },
    [onPairingSuccess]
  );

  const clearPairingSuccess = useCallback(() => setPairingSuccess(false), []);

  const deleteDevice = useCallback(
    async (deviceId: string): Promise<boolean> => {
      setIsDeleting(deviceId);
      setDeleteError(null);
      try {
        const token = localStorage.getItem("token");
        const response = await fetch(`/api/devices?id=${deviceId}`, {
          method: "DELETE",
          headers: { Authorization: `Bearer ${token}` },
        });
        const data = await response.json();
        if (data.success) {
          await mutate("/api/devices");
          onDeleteSuccess?.(deviceId);
          return true;
        }
        setDeleteError(data.error || "Failed to delete device");
        return false;
      } catch {
        setDeleteError("Failed to delete device");
        return false;
      } finally {
        setIsDeleting(null);
      }
    },
    [onDeleteSuccess]
  );

  const updateDevice = useCallback(
    async (deviceId: string, name: string): Promise<boolean> => {
      try {
        const token = localStorage.getItem("token");
        const response = await fetch("/api/devices", {
          method: "PATCH",
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ id: deviceId, name: name.trim() }),
        });
        const data = await response.json();
        if (data.success) {
          await mutate("/api/devices");
          return true;
        }
        return false;
      } catch {
        return false;
      }
    },
    []
  );

  return {
    devices,
    isLoading,
    error: error || null,
    isValidating,
    refresh,
    pairDevice,
    isPairing,
    pairingError,
    pairingSuccess,
    clearPairingSuccess,
    deleteDevice,
    isDeleting,
    deleteError,
    updateDevice,
  };
}
