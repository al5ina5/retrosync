"use client";

import type { Save } from "@/types";
import type { LocationsByDevice } from "./LocationsList";
import { Toggle } from "../ui";
import { Download } from "lucide-react";
import { LocationsList } from "./LocationsList";

export type SaveItemDesktopProps = {
  save: Save;
  expanded: boolean;
  formatRelativeTime: (date: string) => string;
  formatFileSize: (bytes: number) => string;
  syncEnabled: boolean;
  isUpdating: boolean;
  onSyncChange: (checked: boolean) => void;
  locationsByDevice: LocationsByDevice;
};

/** Desktop layout: visible from md and up (hidden by default, block from md up) */
export function SaveItemDesktop({
  save,
  expanded,
  formatRelativeTime,
  formatFileSize,
  syncEnabled,
  isUpdating,
  onSyncChange,
  locationsByDevice,
}: SaveItemDesktopProps) {
  return (
    <div className="hidden md:block">
      <div className="flex">
        <p className="p-2 px-4 border-r-2 border-gameboy-lightest truncate flex-1">
          {save.displayName}
        </p>
        <div
          className="p-2 px-4 border-r-2 border-gameboy-lightest"
          onClick={(e) => e.stopPropagation()}
        >
          <button aria-label="Download">
            <Download size={20} />
          </button>
        </div>
        <div
          className="flex p-2 px-4 gap-2 items-center"
          onClick={(e) => e.stopPropagation()}
        >
          <p>Sync</p>
          <Toggle
            checked={syncEnabled}
            onChange={onSyncChange}
            disabled={isUpdating}
            aria-label={syncEnabled ? "Sync shared (on)" : "Sync per device (off)"}
          />
        </div>
      </div>
      <div className="text-xs border-t-2 border-gameboy-lightest flex">
        <p className="p-2 px-4 border-r-2 border-gameboy-lightest">
          {formatRelativeTime(save.lastModifiedAt)}
        </p>
        <p className="p-2 px-4 border-r-2 border-gameboy-lightest">
          ({formatFileSize(save.fileSize)})
        </p>
        <p className="p-2 px-4 border-r-2 border-gameboy-lightest">
          {save.locations.length} locations
        </p>
      </div>
      {expanded && (
        <div className="p-2 px-4 border-t-2 border-gameboy-lightest">
          <LocationsList locationsByDevice={locationsByDevice} />
        </div>
      )}
    </div>
  );
}
