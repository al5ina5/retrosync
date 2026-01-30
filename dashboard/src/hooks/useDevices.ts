"use client";

import type { Device, DevicesResponse } from "@/types";
import { useDevicesContext } from "@/contexts/DevicesContext";
import { useDevicesState } from "./useDevicesState";

export interface UseDevicesOptions {
  refreshInterval?: number;
  onPairingSuccess?: () => void;
  onDeleteSuccess?: (deviceId: string) => void;
}

export interface UseDevicesReturn {
  devices: Device[];
  isLoading: boolean;
  error: Error | null;
  isValidating: boolean;
  refresh: () => Promise<void>;
  pairDevice: (code: string) => Promise<boolean>;
  isPairing: boolean;
  pairingError: string | null;
  pairingSuccess: boolean;
  clearPairingSuccess: () => void;
  deleteDevice: (deviceId: string) => Promise<boolean>;
  isDeleting: string | null;
  deleteError: string | null;
}

export function useDevices(options: UseDevicesOptions = {}): UseDevicesReturn {
  const context = useDevicesContext();
  if (context != null) return context;
  return useDevicesState(options);
}
