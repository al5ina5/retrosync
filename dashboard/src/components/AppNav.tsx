"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useAuth } from "@/hooks";
import clsx from "clsx";

const activeLinkClass = "bg-gameboy-darkest text-gameboy-lightest";

const RenderLinks = () => {
  const pathname = usePathname();
  const { isAuthenticated, isLoading } = useAuth({
    redirectOnUnauthenticated: false,
  });

  const isActive = (href: string) =>
    href === "/" ? pathname === "/" : pathname.startsWith(href);

  return (
    <>
      <Link href="/" className={clsx(isActive("/") && activeLinkClass)}>
        Home
      </Link>
      {isLoading ? null : isAuthenticated ? (
        <>
          <Link href="/devices" className={clsx(isActive("/devices") && activeLinkClass)}>
            Devices
          </Link>
          <Link href="/saves" className={clsx(isActive("/saves") && activeLinkClass)}>
            Saves
          </Link>
          <Link href="/account" className={clsx(isActive("/account") && activeLinkClass)}>
            Account
          </Link>
        </>
      ) : (
        <Link href="/auth" className={clsx(isActive("/auth") && activeLinkClass)}>
          Sign Up
        </Link>
      )}
    </>
  );
};
export function AppNav() {
  return (
    <>
      <div className="hidden md:flex max-w-xl mx-auto p-12 lg:pt-24 pb-0 items-center justify-center *:px-4 *:py-2">
        <RenderLinks />
      </div>

      <div className="z-[9999] md:hidden fixed bottom-0 w-full overflow-x-auto hide-scrollbar whitespace-nowrap flex border-t-2 border-gameboy-darkest bg-gameboy-lightest *:px-4 *:py-2 *:border-r-2 *:border-gameboy-darkest [&>*:last-child]:border-r-0">
        <RenderLinks />
      </div>
    </>
  );
}
