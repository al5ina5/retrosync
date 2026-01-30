"use client";

import { useState } from "react";
import { useDevices } from "@/hooks";

export function DevicePairForm() {
  const { pairDevice, isPairing, pairingError, pairingSuccess } = useDevices();
  const [code, setCode] = useState("");

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
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
          className="w-full bg-transparent text-center placeholder:text-gameboy-light text-6xl outline-none"
        />
        <div className="flex items-stretch p-2">
          <button type="submit" disabled={isPairing || code.length !== 6} className="bg-gameboy-light text-gameboy-darkest px-6 py-3 whitespace-nowrap">
            {isPairing ? "Pairing..." : "Pair"}
          </button>
        </div>
        {/* {pairingError && <span>{pairingError}</span>}
        {pairingSuccess && <span>Device paired!</span>} */}
      </form>
    </div>
  );
}
