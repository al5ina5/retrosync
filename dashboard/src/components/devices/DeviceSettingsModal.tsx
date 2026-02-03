"use client";

import { useState, useEffect, useMemo } from "react";
import useSWR from "swr";
import type { Device, DeviceScanPathsResponse } from "@/types";
import { Modal, InputWithButton, Button } from "@/components/ui";
import { useDevices } from "@/hooks";
import { fetcher } from "@/lib/fetcher";

type DeviceSettingsModalProps = {
  device: Device | null;
  open: boolean;
  onClose: () => void;
};

export function DeviceSettingsModal({
  device,
  open,
  onClose,
}: DeviceSettingsModalProps) {
  const { updateDevice, deleteDevice, isDeleting } = useDevices();
  const [name, setName] = useState(device?.name ?? "");
  const [nameLoading, setNameLoading] = useState(false);
  const [nameError, setNameError] = useState<string | null>(null);
  const [newPath, setNewPath] = useState("");
  const [pathLoading, setPathLoading] = useState(false);
  const [pathError, setPathError] = useState<string | null>(null);
  const [deletingPathId, setDeletingPathId] = useState<string | null>(null);

  useEffect(() => {
    if (device && open) setName(device.name);
  }, [device?.id, open, device?.name]);

  useEffect(() => {
    if (!open) {
      setNewPath("");
      setPathError(null);
      setPathLoading(false);
    }
  }, [open]);

  const scanPathsKey =
    device && open ? `/api/devices/scan-paths?deviceId=${device.id}` : null;
  const {
    data: scanPathsData,
    isLoading: scanPathsLoading,
    error: scanPathsError,
    mutate: refreshScanPaths,
  } = useSWR<DeviceScanPathsResponse>(scanPathsKey, fetcher);

  const scanPaths = useMemo(() => scanPathsData?.paths ?? [], [scanPathsData]);

  const handleUpdateName = async () => {
    if (!device) return;
    const trimmed = name.trim();
    if (!trimmed) {
      setNameError("Enter a name");
      return;
    }
    if (trimmed === device.name) return;
    setNameError(null);
    setNameLoading(true);
    try {
      const ok = await updateDevice(device.id, trimmed);
      if (ok) onClose();
      else setNameError("Update failed");
    } catch {
      setNameError("Update failed");
    } finally {
      setNameLoading(false);
    }
  };

  const handleDelete = async () => {
    if (!device) return;
    const ok = await deleteDevice(device.id);
    if (ok) onClose();
  };

  const handleDeletePath = async (pathId: string) => {
    if (!device) return;
    setPathError(null);
    setDeletingPathId(pathId);
    try {
      const token = localStorage.getItem("token");
      const response = await fetch(
        `/api/devices/scan-paths?pathId=${encodeURIComponent(pathId)}`,
        {
          method: "DELETE",
          headers: { Authorization: `Bearer ${token}` },
        }
      );
      const data = await response.json();
      if (data.success) {
        await refreshScanPaths();
      } else {
        setPathError(data.error || "Failed to remove path");
      }
    } catch {
      setPathError("Failed to remove path");
    } finally {
      setDeletingPathId(null);
    }
  };

  const handleAddPath = async () => {
    if (!device) return;
    const trimmed = newPath.trim();
    if (!trimmed) {
      setPathError("Enter a path");
      return;
    }
    setPathError(null);
    setPathLoading(true);
    try {
      const token = localStorage.getItem("token");
      const response = await fetch("/api/devices/scan-paths", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ deviceId: device.id, path: trimmed }),
      });
      const data = await response.json();
      if (data.success) {
        setNewPath("");
        await refreshScanPaths();
      } else {
        setPathError(data.error || "Failed to add path");
      }
    } catch {
      setPathError("Failed to add path");
    } finally {
      setPathLoading(false);
    }
  };

  if (!device) return null;

  return (
    <Modal open={open} onClose={onClose} title={device.name}>
      <div className="space-y-6">
        <InputWithButton
          label="Change name"
          type="text"
          placeholder="Device name"
          value={name}
          onChange={(e) => {
            setNameError(null);
            setName(e.target.value);
          }}
          onButtonClick={handleUpdateName}
          buttonLabel="Update"
          loading={nameLoading}
          loadingLabel="Updating…"
          disabled={name.trim() === device.name}
        />
        {nameError != null && (
          <p className="text-sm text-red-600" role="alert">
            {nameError}
          </p>
        )}

        <div className="pt-2 border-t-2 border-gameboy-dark space-y-3">
          <div className="flex items-center justify-between">
            <p className="text-sm font-medium">Scan paths</p>
            {scanPathsLoading && (
              <span className="text-xs text-gameboy-dark">Loading…</span>
            )}
          </div>
          {scanPathsError && (
            <p className="text-sm text-red-600" role="alert">
              Failed to load scan paths
            </p>
          )}
          {scanPaths.length === 0 && !scanPathsLoading && (
            <p className="text-sm text-gameboy-dark">
              No scan paths reported yet.
            </p>
          )}
          {scanPaths.length > 0 && (
            <ul className="space-y-2">
              {scanPaths.map((path) => (
                <li
                  key={path.id}
                  className="border-2 border-gameboy-dark bg-gameboy-light px-3 py-2 flex items-start justify-between gap-2"
                >
                  <div className="min-w-0 flex-1">
                    <p className="text-sm break-all">{path.path}</p>
                    <p className="text-xs text-gameboy-dark">
                      {path.kind === "default" ? "Default" : "Custom"} ·{" "}
                      {path.source === "user" ? "Dashboard" : "Device"}
                    </p>
                  </div>
                  {path.kind === "custom" && (
                    <Button
                      type="button"
                      variant="secondary"
                      onClick={() => handleDeletePath(path.id)}
                      disabled={deletingPathId === path.id}
                      className="shrink-0 border-red-600 text-red-600 hover:bg-red-600 hover:text-white hover:border-red-600 text-xs px-2 py-1"
                    >
                      {deletingPathId === path.id ? "…" : "Remove"}
                    </Button>
                  )}
                </li>
              ))}
            </ul>
          )}

          <InputWithButton
            label="Add path"
            type="text"
            placeholder="/path/to/saves"
            value={newPath}
            onChange={(e) => {
              setPathError(null);
              setNewPath(e.target.value);
            }}
            onButtonClick={handleAddPath}
            buttonLabel="Add"
            loading={pathLoading}
            loadingLabel="Adding…"
            disabled={newPath.trim().length === 0}
          />
          {pathError != null && (
            <p className="text-sm text-red-600" role="alert">
              {pathError}
            </p>
          )}
          <p className="text-xs text-gameboy-dark">
            New paths sync to the device on its next check-in.
          </p>
        </div>

        <div className="pt-2 border-t-2 border-gameboy-dark">
          <Button
            type="button"
            variant="secondary"
            onClick={handleDelete}
            disabled={isDeleting === device.id}
            className="border-red-600 text-red-600 hover:bg-red-600 hover:text-white hover:border-red-600"
          >
            {isDeleting === device.id ? "Deleting…" : "Delete"}
          </Button>
        </div>
      </div>
    </Modal>
  );
}
