"use client";

import { useMemo } from "react";
import { useRouter } from "next/navigation";
import { Button, Modal } from "@/components/ui";
import { getUpgradeLimitCopy } from "@/lib/upgradeLimit";

type UpgradeLimitModalProps = {
  open: boolean;
  onClose: () => void;
  errorMessage?: string | null;
};

export function UpgradeLimitModal({
  open,
  onClose,
  errorMessage,
}: UpgradeLimitModalProps) {
  const router = useRouter();
  const copy = useMemo(() => getUpgradeLimitCopy(errorMessage), [errorMessage]);

  return (
    <Modal open={open} onClose={onClose} title={copy.title}>
      <div className="space-y-3">
        <p>{copy.lead}</p>
        <p>{copy.body}</p>
        <p className="text-sm text-gameboy-dark">
          Consider this a power-up for your saves.
        </p>
        <div className="flex flex-wrap gap-2 pt-2">
          <Button onClick={() => router.push("/upgrade")}>
            Upgrade to Pro
          </Button>
          <Button variant="secondary" onClick={onClose}>
            Not now
          </Button>
        </div>
      </div>
    </Modal>
  );
}
