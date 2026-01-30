"use client";

import { formatDistanceToNow } from "date-fns";
import type { Device } from "@/types";
import { useDevices } from "@/hooks";

type DeviceItemProps = {
  device: Device;
};

export function DeviceItem({ device }: DeviceItemProps) {
  const { deleteDevice, isDeleting } = useDevices();

  return (
    <li className="bg-gameboy-light p-6 space-y-6">
      <p className="text-4xl">{device.name}</p>
      {device.lastSyncAt && (
        <p>{formatDistanceToNow(new Date(device.lastSyncAt))}</p>
      )}
      {/* <button
        type="button"
        onClick={() => deleteDevice(device.id)}
        disabled={isDeleting === device.id}
      >
        {isDeleting === device.id ? "Deleting..." : "Delete"}
      </button> */}
    </li>
  );
}
