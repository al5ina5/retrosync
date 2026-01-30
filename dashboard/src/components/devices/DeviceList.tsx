"use client";

import { useDevices } from "@/hooks";
import { DeviceItem } from "./DeviceItem";

export function DeviceList() {
  const { devices, isLoading, error, deleteError, refresh } = useDevices();

  if (isLoading) return <div>Loading devices...</div>;

  return (
    <>
      {error && <div>{error.message}</div>}
      {deleteError && <div>{deleteError}</div>}
      <ul className="grid grid-cols-2 gap-6">
        {devices.map((device) => (
          <DeviceItem key={device.id} device={device} />
        ))}
      </ul>
      {devices.length === 0 && <p>No devices paired yet.</p>}
    </>
  );
}
