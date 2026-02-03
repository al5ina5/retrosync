"use client";

import { useEffect, useState } from "react";
import { useDevices } from "@/hooks";
import { UpgradeLimitModal } from "@/components/upgrade";
import { isUpgradeLimitError } from "@/lib/upgradeLimit";

const FREE_MAX_DEVICES = 2;

export function DevicePairForm() {
  const { devices, pairDevice, isPairing, pairingError, pairingSuccess } = useDevices();
  const [code, setCode] = useState("");
  const [upgradeModalOpen, setUpgradeModalOpen] = useState(false);
  const [upgradeMessage, setUpgradeMessage] = useState<string | null>(null);
  const isLimitError = isUpgradeLimitError(pairingError);
  const isAtDeviceLimit = devices.length >= FREE_MAX_DEVICES;

  useEffect(() => {
    if (isLimitError) {
      setUpgradeMessage(pairingError);
      setUpgradeModalOpen(true);
    }
  }, [isLimitError, pairingError]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (isAtDeviceLimit) {
      setUpgradeMessage(
        `Free plan allows up to ${FREE_MAX_DEVICES} devices. Upgrade to add more.`
      );
      setUpgradeModalOpen(true);
      return;
    }
    const success = await pairDevice(code);
    if (success) setCode("");
  };

  return (
    <div className="border-4 border-gameboy-light">
      <form onSubmit={handleSubmit} className="flex">
        <input
          type="text"
          value={code}
          onChange={(e) => setCode(e.target.value.toUpperCase())}
          placeholder="000000"
          maxLength={6}
          className="w-full bg-transparent text-center placeholder:text-gameboy-light text-2xl md:text-6xl outline-none"
        />
        <div className="flex items-stretch p-2">
          <button type="submit" disabled={isPairing || code.length !== 6} className="bg-gameboy-light text-gameboy-darkest px-6 py-3 whitespace-nowrap">
            {isPairing ? "Pairing..." : "Pair"}
          </button>
        </div>
      </form>
      {pairingError && !isLimitError && (
        <p className="p-2 text-sm text-red-600">{pairingError}</p>
      )}
      {pairingSuccess && <p className="p-2 text-sm text-green-700">Device paired!</p>}
      <UpgradeLimitModal
        open={upgradeModalOpen}
        onClose={() => setUpgradeModalOpen(false)}
        errorMessage={upgradeMessage ?? pairingError}
      />
    </div>
  );
}
