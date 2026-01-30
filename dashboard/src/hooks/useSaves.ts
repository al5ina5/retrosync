"use client";

import type { Save, SavesResponse, SyncStrategy } from "@/types";
import { useSavesContext } from "@/contexts/SavesContext";
import { useSavesState } from "./useSavesState";

export interface UseSavesOptions {
  refreshInterval?: number;
  onDeleteSuccess?: (saveId: string) => void;
  onStrategyChange?: (saveId: string, strategy: SyncStrategy) => void;
}

export interface UseSavesReturn {
  saves: Save[];
  count: number;
  isLoading: boolean;
  error: Error | null;
  isValidating: boolean;
  refresh: () => Promise<void>;
  downloadSave: (saveKey: string, fileName: string, deviceId?: string) => Promise<boolean>;
  isDownloading: string | null;
  downloadError: string | null;
  requestDelete: (saveId: string) => void;
  cancelDelete: () => void;
  deleteConfirmId: string | null;
  deleteSave: (saveId: string) => Promise<boolean>;
  isDeleting: string | null;
  deleteError: string | null;
  setSyncStrategy: (saveId: string, strategy: SyncStrategy) => Promise<boolean>;
  isUpdatingStrategy: string | null;
  strategyError: string | null;
  formatFileSize: (bytes: number) => string;
  formatRelativeTime: (isoString: string) => string;
}

export function useSaves(options: UseSavesOptions = {}): UseSavesReturn {
  const context = useSavesContext();
  if (context != null) return context;
  return useSavesState(options);
}
