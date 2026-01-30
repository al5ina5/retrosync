"use client";

import type { Save } from "@/types";
import { useSaves } from "@/hooks";
import { useMemo } from "react";
import clsx from "clsx";
import { SaveItemMobile } from "./SaveItemMobile";
import { SaveItemDesktop } from "./SaveItemDesktop";

type SaveItemProps = {
  save: Save;
  expanded: boolean;
  onToggleExpand: () => void;
};

export function SaveItem({ save, expanded, onToggleExpand }: SaveItemProps) {
  const { formatFileSize, formatRelativeTime, setSyncStrategy, isUpdatingStrategy } = useSaves();

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

  const shared = {
    save,
    expanded,
    formatRelativeTime,
    formatFileSize,
    syncEnabled,
    isUpdating,
    onSyncChange: handleSyncChange,
    locationsByDevice,
  };

  return (
    <li
      className={clsx(
        "cursor-pointer",
        "md:hover:bg-gameboy-darkest md:hover:text-gameboy-light",
        expanded ? "bg-gameboy-darkest text-gameboy-light" : "bg-gameboy-light"
      )}
      onClick={onToggleExpand}
    >
      <SaveItemMobile {...shared} />
      <SaveItemDesktop {...shared} />
    </li>
  );
}
