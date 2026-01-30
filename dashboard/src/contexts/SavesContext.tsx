"use client";

import { createContext, useContext } from "react";
import type { UseSavesReturn } from "@/hooks/useSaves";
import { useSavesState } from "@/hooks/useSavesState";

const SavesContext = createContext<UseSavesReturn | null>(null);

export function SavesProvider({ children }: { children: React.ReactNode }) {
  const value = useSavesState({});
  return <SavesContext.Provider value={value}>{children}</SavesContext.Provider>;
}

export function useSavesContext(): UseSavesReturn | null {
  return useContext(SavesContext);
}
