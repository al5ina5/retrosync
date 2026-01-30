"use client";

import Link from "next/link";
import { useAuth } from "@/hooks";

export function AppNav() {
  const { isAuthenticated, isLoading, logout } = useAuth({
    redirectOnUnauthenticated: false,
  });

  return (
    <nav className="max-w-xl mx-auto p-12 lg:pt-24 pb-0 space-x-4 flex items-center justify-center">
      <Link href="/">Home</Link>
      {isLoading ? null : isAuthenticated ? (
        <>
          <Link href="/devices">Devices</Link>
          <Link href="/saves">Saves</Link>
          <button type="button" onClick={logout}>
            Logout
          </button>
        </>
      ) : (
        <Link href="/auth">Sign In / Register</Link>
      )}
    </nav>
  );
}
