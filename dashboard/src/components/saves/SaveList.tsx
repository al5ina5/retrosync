"use client";

import { useEffect, useMemo, useState } from "react";
import { useSaves } from "@/hooks";
import { UpgradeLimitModal } from "@/components/upgrade";
import { isUpgradeLimitError } from "@/lib/upgradeLimit";
import { SaveItem } from "./SaveItem";

export function SaveList() {
  const {
    saves,
    isLoading,
    error,
    downloadError,
    deleteError,
    strategyError,
  } = useSaves();
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [upgradeModalOpen, setUpgradeModalOpen] = useState(false);

  const isStrategyLimit = isUpgradeLimitError(strategyError);
  const isDownloadLimit = isUpgradeLimitError(downloadError);
  const isDeleteLimit = isUpgradeLimitError(deleteError);

  const limitErrorMessage = useMemo(() => {
    if (isStrategyLimit) return strategyError ?? null;
    if (isDownloadLimit) return downloadError ?? null;
    if (isDeleteLimit) return deleteError ?? null;
    return null;
  }, [
    isStrategyLimit,
    isDownloadLimit,
    isDeleteLimit,
    strategyError,
    downloadError,
    deleteError,
  ]);

  useEffect(() => {
    if (limitErrorMessage) setUpgradeModalOpen(true);
  }, [limitErrorMessage]);

  if (isLoading) return <div>Loading saves...</div>;

  return (
    <>
      {error && <div>{error.message}</div>}
      {strategyError && !isStrategyLimit && <div>{strategyError}</div>}
      {downloadError && !isDownloadLimit && <div>{downloadError}</div>}
      {deleteError && !isDeleteLimit && <div>{deleteError}</div>}
      <UpgradeLimitModal
        open={upgradeModalOpen}
        onClose={() => setUpgradeModalOpen(false)}
        errorMessage={limitErrorMessage}
      />
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
