"use client";

import Image from "next/image";
import { useAuth } from "@/hooks";

export default function HomePage() {
  const { isAuthenticated, isLoading } = useAuth({
    redirectOnUnauthenticated: false,
  });

  if (isLoading) return <div>Loading...</div>;

  return (
    <div className="max-w-xl mx-auto p-12 text-center">
      <Image
        src="/retrosync-mascot.png"
        alt="RetroSync mascot"
        width={160}
        height={160}
        className="mx-auto mb-6 h-40 w-auto object-contain"
      />
      <h1 className="font-minecraft">RetroSync</h1>
      {isAuthenticated ? (
        <p>
          <a href="/devices">Devices</a>
        </p>
      ) : (
        <p>Sync your retro game saves across devices.</p>
      )}
    </div>
  );
}
