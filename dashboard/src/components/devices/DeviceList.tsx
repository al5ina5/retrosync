"use client";

import { useState } from "react";
import type { Device } from "@/types";
import { useDevices } from "@/hooks";
import { DeviceItem } from "./DeviceItem";
import { DeviceSettingsModal } from "./DeviceSettingsModal";

export function DeviceList() {
  const { devices, isLoading, error, deleteError } = useDevices();
  const [selectedDevice, setSelectedDevice] = useState<Device | null>(null);

  if (isLoading) return <div>Loading devices...</div>;

  return (
    <>
      {error && <div>{error.message}</div>}
      {deleteError && <div>{deleteError}</div>}
      <ul className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {devices.map((device) => (
          <DeviceItem
            key={device.id}
            device={device}
            onClick={() => setSelectedDevice(device)}
          />
        ))}
      </ul>
      {devices.length === 0 && <p>No devices paired yet.</p>}
      <DeviceSettingsModal
        device={selectedDevice}
        open={selectedDevice != null}
        onClose={() => setSelectedDevice(null)}
      />
    </>
  );
}
