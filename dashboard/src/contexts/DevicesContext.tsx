"use client";

import { createContext, useContext } from "react";
import type { UseDevicesReturn } from "@/hooks/useDevices";
import { useDevicesState } from "@/hooks/useDevicesState";

const DevicesContext = createContext<UseDevicesReturn | null>(null);

export function DevicesProvider({ children }: { children: React.ReactNode }) {
  const value = useDevicesState({});
  return <DevicesContext.Provider value={value}>{children}</DevicesContext.Provider>;
}

export function useDevicesContext(): UseDevicesReturn | null {
  return useContext(DevicesContext);
}
