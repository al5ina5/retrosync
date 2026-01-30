"use client";

import type { SaveLocation } from "@/types";

type SaveLocationsProps = {
  locations: SaveLocation[];
};

export function SaveLocations({ locations }: SaveLocationsProps) {
  if (locations.length === 0) return null;

  return (
    <ul>
      {locations.map((loc) => (
        <li key={loc.id}>
          {loc.deviceName} — {loc.localPath}
          {loc.isLatest && " (latest)"}
        </li>
      ))}
    </ul>
  );
}
