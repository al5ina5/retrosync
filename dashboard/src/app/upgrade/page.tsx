"use client";

import { useRouter } from "next/navigation";
import { useAuthContext } from "@/contexts/AuthContext";
import Layout from "@/components/ui/Layout";
import { Button } from "@/components/ui";
import { UpgradePitch } from "@/components/upgrade";
import { useUpgradeCheckout } from "@/hooks";

export default function UpgradePage() {
  const router = useRouter();
  const auth = useAuthContext();
  const isAuthenticated = auth?.isAuthenticated ?? false;
  const authLoading = auth?.isLoading ?? true;
  const getToken = auth?.getToken ?? (() => null);
  const {
    startCheckout,
    isLoading: checkoutLoading,
    error: checkoutError,
  } = useUpgradeCheckout({ getToken });

  if (auth === null) return <div>Loading...</div>;
  if (authLoading) return <div>Loading...</div>;
  if (!isAuthenticated) {
    router.push("/auth");
    return null;
  }

  return (
    <Layout>
      <UpgradePitch />

      <div>
        <button
          type="button"
          onClick={startCheckout}
          disabled={checkoutLoading}
          className="border-4 border-gameboy-darkest bg-gameboy-darkest text-gameboy-lightest hover:bg-gameboy-lightest hover:text-gameboy-darkest px-6 py-3 whitespace-nowrap text-lg md:text-2xl disabled:opacity-50"
        >
          {checkoutLoading ? "Redirecting..." : "Upgrade for $6/mo"}
        </button>
        {checkoutError && (
          <p className="mt-2 text-red-600 dark:text-red-400 text-sm">{checkoutError}</p>
        )}
      </div>

      <div className="space-y-2 opacity-50 p-6">
        <p className="">...It&apos;s not free?</p>
        <p>How else am I supposed to acquire more unused devices to sit in my closet?</p>
      </div>


      <div className="flex justify-center">
        <Button variant="primary" onClick={() => auth?.logout()}>
          Logout
        </Button>
      </div>
    </Layout>
  );
}
