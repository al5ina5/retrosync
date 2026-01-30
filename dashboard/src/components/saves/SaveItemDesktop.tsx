"use client";

import type { Save } from "@/types";
import { Toggle } from "../ui";
import type { LocationsByDevice } from "./LocationsList";
import { LocationsList } from "./LocationsList";

export type SaveItemDesktopProps = {
  save: Save;
  expanded: boolean;
  formatRelativeTime: (date: string) => string;
  syncEnabled: boolean;
  isUpdating: boolean;
  onSyncChange: (checked: boolean) => void;
  onDownload?: (saveKey: string, fileName: string) => void;
  isDownloading?: boolean;
  locationsByDevice: LocationsByDevice;
};

/** Desktop layout: visible from md and up (hidden by default, block from md up) */
export function SaveItemDesktop({
  save,
  expanded,
  formatRelativeTime,
  syncEnabled,
  isUpdating,
  onSyncChange,
  onDownload,
  isDownloading,
  locationsByDevice,
}: SaveItemDesktopProps) {
  return (
    <div className="hidden md:block">
      <div className="border-t-2 border-gameboy-lightest flex justify-end text-xs">
        <div
          className="p-2 px-4 border-r-2 border-gameboy-lightest">

        </div>
        <div
          className="p-2 px-4 border-r-2 border-gameboy-lightest"
          onClick={(e) => e.stopPropagation()}
        >
          <button
            type="button"
            aria-label={isDownloading ? "Downloading…" : "Download"}
            disabled={isDownloading}
            onClick={() => onDownload?.(save.saveKey, save.displayName)}
            className="disabled:opacity-50 disabled:cursor-not-allowed"
          >
            Download
            {/* <Download size={20} /> */}
          </button>
        </div>
        <div
          className="flex p-2 px-4 gap-2 items-center"
          onClick={(e) => e.stopPropagation()}
        >
          <Toggle
            label="Sync"
            checked={syncEnabled}
            onChange={onSyncChange}
            disabled={isUpdating}
            aria-label={syncEnabled ? "Sync shared (on)" : "Sync per device (off)"}
          />
        </div>
      </div>

      <div className="border-t-2 border-gameboy-lightest flex">
        <p className="p-2 px-4 truncate flex-1">
          {save.displayName}
        </p>

      </div>
      <div className="text-xs border-t-2 border-gameboy-lightest flex *:flex-1 *:border-r-2 *:border-gameboy-lightest [&>*:last-child]:border-r-0">
        <p className="p-2 px-4 ">
          {formatRelativeTime(save.uploadedAt ?? save.lastModifiedAt)}
        </p>
        <p className="p-2 px-4 ">
          {locationsByDevice.length} {locationsByDevice.length === 1 ? "device" : "devices"}
        </p>
        <p className="p-2 px-4 ">
          {save.locations.length}  {save.locations.length === 1 ? "location" : "locations"}
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
