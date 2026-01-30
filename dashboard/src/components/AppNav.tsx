"use client";

import Link from "next/link";
import { useAuth } from "@/hooks";

const RenderLinks = () => {
  const { isAuthenticated, isLoading, logout } = useAuth({
    redirectOnUnauthenticated: false,
  });
  return <>
    <Link href="/">Home</Link>
    {
      isLoading ? null : isAuthenticated ? (
        <>
          <Link href="/devices">Devices</Link>
          <Link href="/saves">Saves</Link>
          <Link href="/account">Account</Link>
        </>
      ) : (
        <Link href="/auth">Sign Up</Link>
      )
    }</>
}
export function AppNav() {

  return (
    <>
      <div className="hidden md:flex max-w-xl mx-auto p-12 lg:pt-24 pb-0 space-x-4 items-center justify-center">
        <RenderLinks />
      </div>

      <div className="z-[9999] md:hidden fixed bottom-0 w-full overflow-x-auto hide-scrollbar whitespace-nowrap flex border-t-2 border-gameboy-darkest bg-gameboy-lightest *:px-4 *:py-2 *:border-r-2 *:border-gameboy-darkest [&>*:last-child]:border-r-0">
        <RenderLinks />
      </div>
    </>
  );
}
