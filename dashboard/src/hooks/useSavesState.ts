"use client";

import { useState, useCallback } from "react";
import useSWR, { mutate } from "swr";
import { fetcher } from "@/lib/fetcher";
import type { SavesResponse, SyncStrategy } from "@/types";
import type { UseSavesOptions, UseSavesReturn } from "./useSaves";

function formatFileSize(bytes: number): string {
  if (bytes === 0) return "0 B";
  const k = 1024;
  const sizes = ["B", "KB", "MB", "GB"];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return Math.round((bytes / Math.pow(k, i)) * 100) / 100 + " " + sizes[i];
}

function formatRelativeTime(isoString: string): string {
  const dt = new Date(isoString);
  if (Number.isNaN(dt.getTime())) return "";
  const now = new Date();
  const diffMs = now.getTime() - dt.getTime();
  if (diffMs < 0) return "just now";
  const diffSeconds = Math.floor(diffMs / 1000);
  const diffMinutes = Math.floor(diffSeconds / 60);
  const diffHours = Math.floor(diffMinutes / 60);
  const diffDays = Math.floor(diffHours / 24);
  const diffMonths = Math.floor(diffDays / 30);
  const diffYears = Math.floor(diffDays / 365);
  if (diffSeconds < 60) return diffSeconds <= 1 ? "1 second ago" : `${diffSeconds} seconds ago`;
  if (diffMinutes < 60) return diffMinutes === 1 ? "1 minute ago" : `${diffMinutes} minutes ago`;
  if (diffHours < 24) return diffHours === 1 ? "1 hour ago" : `${diffHours} hours ago`;
  if (diffDays < 30) return diffDays === 1 ? "1 day ago" : `${diffDays} days ago`;
  if (diffMonths < 12) return diffMonths === 1 ? "1 month ago" : `${diffMonths} months ago`;
  return diffYears === 1 ? "1 year ago" : `${diffYears} years ago`;
}

export function useSavesState(options: UseSavesOptions = {}): UseSavesReturn {
  const { refreshInterval = 0, onDeleteSuccess, onStrategyChange } = options;
  const [isDownloading, setIsDownloading] = useState<string | null>(null);
  const [downloadError, setDownloadError] = useState<string | null>(null);
  const [deleteConfirmId, setDeleteConfirmId] = useState<string | null>(null);
  const [isDeleting, setIsDeleting] = useState<string | null>(null);
  const [deleteError, setDeleteError] = useState<string | null>(null);
  const [isUpdatingStrategy, setIsUpdatingStrategy] = useState<string | null>(null);
  const [strategyError, setStrategyError] = useState<string | null>(null);

  const { data, error, isLoading, isValidating } = useSWR<SavesResponse>(
    typeof window !== "undefined" && localStorage.getItem("token") ? "/api/saves" : null,
    fetcher,
    { refreshInterval }
  );

  const saves = data?.saves || [];
  const count = data?.count || 0;

  const refresh = useCallback(async () => {
    await mutate("/api/saves");
  }, []);

  const downloadSave = useCallback(
    async (saveKey: string, fileName: string, deviceId?: string): Promise<boolean> => {
      const downloadKey = deviceId ? `${saveKey}::${deviceId}` : saveKey;
      setIsDownloading(downloadKey);
      setDownloadError(null);
      try {
        const token = localStorage.getItem("token");
        const params = new URLSearchParams({ filePath: saveKey });
        if (deviceId) params.append("deviceId", deviceId);
        const res = await fetch(`/api/saves/download?${params}`, {
          headers: { Authorization: `Bearer ${token}` },
        });
        const body = await res.json();
        if (!res.ok || !body?.success || !body?.data?.url) {
          setDownloadError(body?.error || "Failed to generate download link");
          return false;
        }
        window.location.href = body.data.url;
        return true;
      } catch {
        setDownloadError(`Failed to download ${fileName}`);
        return false;
      } finally {
        setIsDownloading(null);
      }
    },
    []
  );

  const requestDelete = useCallback((saveId: string) => {
    setDeleteConfirmId(saveId);
    setDeleteError(null);
  }, []);

  const cancelDelete = useCallback(() => setDeleteConfirmId(null), []);

  const deleteSave = useCallback(
    async (saveId: string): Promise<boolean> => {
      setIsDeleting(saveId);
      setDeleteError(null);
      try {
        const token = localStorage.getItem("token");
        const response = await fetch(
          `/api/saves?saveId=${encodeURIComponent(saveId)}`,
          { method: "DELETE", headers: { Authorization: `Bearer ${token}` } }
        );
        const data = await response.json();
        if (data.success) {
          await mutate("/api/saves");
          setDeleteConfirmId(null);
          onDeleteSuccess?.(saveId);
          return true;
        }
        setDeleteError(data.error || "Failed to delete save");
        return false;
      } catch {
        setDeleteError("Failed to delete save");
        return false;
      } finally {
        setIsDeleting(null);
      }
    },
    [onDeleteSuccess]
  );

  const setSyncStrategy = useCallback(
    async (saveId: string, strategy: SyncStrategy): Promise<boolean> => {
      setIsUpdatingStrategy(saveId);
      setStrategyError(null);
      try {
        const token = localStorage.getItem("token");
        const res = await fetch("/api/saves/set-sync-strategy", {
          method: "PATCH",
          headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
          body: JSON.stringify({ saveId, syncStrategy: strategy }),
        });
        const body = await res.json();
        if (!res.ok || !body?.success) {
          setStrategyError(body?.error || "Failed to set sync strategy");
          return false;
        }
        await mutate("/api/saves");
        onStrategyChange?.(saveId, strategy);
        return true;
      } catch {
        setStrategyError("Failed to set sync strategy");
        return false;
      } finally {
        setIsUpdatingStrategy(null);
      }
    },
    [onStrategyChange]
  );

  return {
    saves,
    count,
    isLoading,
    error: error || null,
    isValidating,
    refresh,
    downloadSave,
    isDownloading,
    downloadError,
    requestDelete,
    cancelDelete,
    deleteConfirmId,
    deleteSave,
    isDeleting,
    deleteError,
    setSyncStrategy,
    isUpdatingStrategy,
    strategyError,
    formatFileSize,
    formatRelativeTime,
  };
}
