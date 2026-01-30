"use client";

import Image from "next/image";
import { useAuth } from "@/hooks";
import Layout from "@/components/ui/Layout";
import { Link } from "lucide-react";

export default function HomePage() {
  const { isAuthenticated, isLoading } = useAuth({
    redirectOnUnauthenticated: false,
  });

  if (isLoading) return <div>Loading...</div>;

  return (
    <Layout>
      <div className="space-y-6 text-center">
        <h1 className="text-3xl lg:text-5xl">RetroSync</h1>
        <p className="text-xl lg:text-3xl">Want your game saves synced across your  retro handhelds?</p>
      </div>

      <div className="flex flex-col space-y-12 items-center text-center">
        <p className="lg:text-2xl">Sync your retro game saves across devices for less than a cup of coffee $6/mo.</p>
        <div>
          <a href="/devices" className="border-4 border-gameboy-darkest bg-gameboy-darkest text-gameboy-lightest hover:bg-gameboy-lightest hover:text-gameboy-darkest px-6 py-3 whitespace-nowrap lg:text-2xl">
            Get Started Now
          </a>
        </div>
      </div>

      <div className="text-center space-y-6">
        <p className="font-medium">Compatibility</p>
        <div className="flex flex-col gap-4 items-center">
          <div className="space-y-2">
            <p className="text-sm text-gameboy-darkest/80">Devices</p>
            <div className="flex flex-wrap gap-2 justify-center">
              {['Computer', 'Ambernic', 'Miyoo Flip'].map((device) => (
                <div key={device} className="text-xs whitespace-nowrap p-2 px-4 border-2 border-gameboy-darkest">
                  {device}
                </div>
              ))}
            </div>
          </div>
          <div className="space-y-2">
            <p className="text-sm text-gameboy-darkest/80">Operating systems</p>
            <div className="flex flex-wrap gap-2 justify-center">
              {['MacOS', 'Windows', 'Linux', 'muOS', 'spruceOS'].map((os) => (
                <div key={os} className="text-xs whitespace-nowrap p-2 px-4 border-2 border-gameboy-darkest">
                  {os}
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </Layout>
  );
}
