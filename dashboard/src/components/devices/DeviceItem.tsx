"use client";

import { formatDistanceToNow } from "date-fns";
import type { Device } from "@/types";

type DeviceItemProps = {
  device: Device;
  onClick?: () => void;
};

export function DeviceItem({ device, onClick }: DeviceItemProps) {
  return (
    <li>
      <button
        type="button"
        onClick={onClick}
        className="w-full text-left bg-gameboy-light p-6 space-y-6 hover:bg-gameboy-lightest transition-colors border-2 border-transparent hover:border-gameboy-dark rounded"
      >
        <p className="text-4xl">{device.name}</p>
        {device.lastSyncAt && (
          <p>{formatDistanceToNow(new Date(device.lastSyncAt))}</p>
        )}
      </button>
    </li>
  );
}
