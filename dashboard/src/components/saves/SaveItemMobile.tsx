"use client";

import type { Save } from "@/types";
import type { LocationsByDevice } from "./LocationsList";
import { Toggle } from "../ui";
import { Download } from "lucide-react";
import { LocationsList } from "./LocationsList";

export type SaveItemMobileProps = {
  save: Save;
  expanded: boolean;
  formatRelativeTime: (date: string) => string;
  formatFileSize: (bytes: number) => string;
  syncEnabled: boolean;
  isUpdating: boolean;
  onSyncChange: (checked: boolean) => void;
  onDownload?: (saveKey: string, fileName: string) => void;
  isDownloading?: boolean;
  locationsByDevice: LocationsByDevice;
};

/** Mobile layout: visible only below md (block by default, hidden from md up) */
export function SaveItemMobile({
  save,
  expanded,
  formatRelativeTime,
  formatFileSize,
  syncEnabled,
  isUpdating,
  onSyncChange,
  onDownload,
  isDownloading,
  locationsByDevice,
}: SaveItemMobileProps) {
  return (
    <div className="md:hidden">
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

        <p className="p-2 px-4 flex-1">
          {save.displayName}
        </p>

      </div>

      {/* <div className="flex border-t-2 border-gameboy-lightest">
        <div
          className=" p-2 px-4 border-r-2 border-gameboy-lightest"
          onClick={(e) => e.stopPropagation()}
        >
          <button
            type="button"
            aria-label={isDownloading ? "Downloading…" : "Download"}
            disabled={isDownloading}
            onClick={() => onDownload?.(save.saveKey, save.displayName)}
            className="disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <Download size={20} />
          </button>
        </div>
        <div
          className="flex gap-2 p-2 px-4 border-r-2 border-gameboy-lightest"
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
        <button className="px-4">Expand</button>
      </div> */}

      <div className="text-xs whitespace-nowrap border-t-2 border-gameboy-lightest fle justify-center text-center">
        <p className="p-2 px-4">
          {formatRelativeTime(save.uploadedAt ?? save.lastModifiedAt)}
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
