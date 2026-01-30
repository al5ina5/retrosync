"use client";

import { useState } from "react";
import { useSaves } from "@/hooks";
import { SaveItem } from "./SaveItem";

export function SaveList() {
  const { saves, isLoading, error, downloadError, deleteError, refresh } = useSaves();
  const [expandedId, setExpandedId] = useState<string | null>(null);

  if (isLoading) return <div>Loading saves...</div>;

  return (
    <>
      {/* {error && <div>{error.message}</div>}
      {downloadError && <div>{downloadError}</div>}
      {deleteError && <div>{deleteError}</div>} */}
      <ul className="space-y-6">
        {saves.map((save) => (
          <SaveItem
            key={save.id}
            save={save}
            expanded={expandedId === save.id}
            onToggleExpand={() => setExpandedId((prev) => (prev === save.id ? null : save.id))}
          />
        ))}
      </ul>
      {saves.length === 0 && <p>No saves yet.</p>}
    </>
  );
}
