"use client";

import type { Save } from "@/types";
import { useSaves } from "@/hooks";

type SaveActionsProps = {
  save: Save;
};

export function SaveActions({ save }: SaveActionsProps) {
  const {
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

  const toggleStrategy = () =>
    setSyncStrategy(save.id, save.syncStrategy === "shared" ? "per_device" : "shared");

  return (
    <div>
      <button
        type="button"
        onClick={() => downloadSave(save.saveKey, save.displayName)}
        disabled={isDownloading === save.saveKey}
      >
        {isDownloading === save.saveKey ? "Downloading..." : "Download"}
      </button>
      <button
        type="button"
        onClick={toggleStrategy}
        disabled={isUpdatingStrategy === save.id}
      >
        {isUpdatingStrategy === save.id
          ? "..."
          : save.syncStrategy === "shared"
            ? "Per-Device"
            : "Shared"}
      </button>
      {deleteConfirmId === save.id ? (
        <>
          <button
            type="button"
            onClick={() => deleteSave(save.id)}
            disabled={isDeleting === save.id}
          >
            {isDeleting === save.id ? "Deleting..." : "Confirm Delete"}
          </button>
          <button type="button" onClick={cancelDelete}>
            Cancel
          </button>
        </>
      ) : (
        <button type="button" onClick={() => requestDelete(save.id)}>
          Delete
        </button>
      )}
    </div>
  );
}
