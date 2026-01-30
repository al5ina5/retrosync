"use client";

import type { Save } from "@/types";
import { useSaves } from "@/hooks";
import { SaveActions } from "./SaveActions";
import { Toggle } from "../ui";
import { Download } from "lucide-react";
import { useMemo } from "react";
import clsx from "clsx";

type SaveItemProps = {
  save: Save;
  expanded: boolean;
  onToggleExpand: () => void;
};

export function SaveItem({ save, expanded, onToggleExpand }: SaveItemProps) {
  const {
    formatFileSize,
    formatRelativeTime,
    downloadSave,
    isDownloading,
    setSyncStrategy,
    isUpdatingStrategy,
    deleteConfirmId,
    requestDelete,
    cancelDelete,
    deleteSave,
    isDeleting,
  } = useSaves();

  const syncEnabled = save.syncStrategy === "shared";
  const isUpdating = isUpdatingStrategy === save.id;

  const handleSyncChange = async (checked: boolean) => {
    await setSyncStrategy(save.id, checked ? "shared" : "per_device");
  };

  const locationsByDevice = useMemo(() => {
    const map = new Map<string, { name: string; paths: string[] }>();
    for (const loc of save.locations) {
      const existing = map.get(loc.deviceId);
      if (existing) {
        existing.paths.push(loc.localPath);
      } else {
        map.set(loc.deviceId, { name: loc.deviceName, paths: [loc.localPath] });
      }
    }
    return Array.from(map.entries());
  }, [save.locations]);

  return (
    <li
      className={clsx(
        "cursor-pointer",
        "hover:bg-gameboy-darkest hover:text-gameboy-light",
        expanded ? "bg-gameboy-darkest text-gameboy-light" : "bg-gameboy-light"
      )}
      onClick={onToggleExpand}
    >
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
            onChange={handleSyncChange}
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
          <ul className="space-y-2">
            {locationsByDevice.map(([deviceId, { name, paths }]) => (
              <li key={deviceId}>
                <span className="font-medium">{name}</span>
                <ul className="mt-1 ml-2 space-y-0.5 text-sm">
                  {paths.map((path, i) => (
                    <li key={`${deviceId}-${i}`} className="truncate">
                      {path}
                    </li>
                  ))}
                </ul>
              </li>
            ))}
          </ul>
        </div>
      )}


      {/* <span> ({formatFileSize(save.fileSize)})</span> */}
      {/* <span> — {formatRelativeTime(save.lastModifiedAt)}</span> */}
      {/* <span> — {save.syncStrategy}</span> */}
      {/* <SaveActions save={save} /> */}
      {/* <SaveLocations locations={save.locations} /> */}
    </li>
  );
}
