"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useAuthContext } from "@/contexts/AuthContext";
import Layout from "@/components/ui/Layout";
import { Button } from "@/components/ui";

export default function UpgradePage() {
  const router = useRouter();
  const auth = useAuthContext();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (auth === null) return <div>Loading...</div>;
  const { isAuthenticated, isLoading: authLoading, getToken } = auth;

  if (authLoading) return <div>Loading...</div>;
  if (!isAuthenticated) {
    router.push("/auth");
    return null;
  }

  async function handlePay() {
    setError(null);
    setLoading(true);
    const token = getToken();
    if (!token) {
      setError("Not signed in.");
      setLoading(false);
      return;
    }
    try {
      const res = await fetch("/api/upgrade/checkout", {
        method: "POST",
        headers: { Authorization: `Bearer ${token}` },
      });
      const json = await res.json();
      if (!res.ok) {
        setError(json.error ?? "Checkout failed");
        setLoading(false);
        return;
      }
      if (json.data?.url) {
        window.location.href = json.data.url;
        return;
      }
      setError("No checkout URL returned");
    } catch {
      setError("Network error");
    }
    setLoading(false);
  }

  return (
    <Layout>
      <div className="space-y-6">
        <h1 className="text-2xl lg:text-3xl">
          It&apos;s time to get you into the club.
        </h1>
        <p className="lg:text-xl">
          You are stuck in free account hell. Please upgrade to a paid account to access all of RetroSync&apos;s premium features and join the secret community.
        </p>
        <div className="space-y-2 lg:text-xl">
          <p>- Unlimited devices</p>
          <p>- Unlimited saves</p>
          <p>- Unlimited games</p>
          <p>- Unlimited syncs</p>
          <p>- Only one plan</p>
          <p>- No buillshit pricing tiers</p>
          <p>- What you see is what you get</p>
        </div>
      </div>

      <div>
        <button
          type="button"
          onClick={handlePay}
          disabled={loading}
          className="border-4 border-gameboy-darkest bg-gameboy-darkest text-gameboy-lightest hover:bg-gameboy-lightest hover:text-gameboy-darkest px-6 py-3 whitespace-nowrap text-lg md:text-2xl disabled:opacity-50"
        >
          {loading ? "Redirecting…" : "Upgrade for $6/mo"}
        </button>
        {error && (
          <p className="mt-2 text-red-600 dark:text-red-400 text-sm">{error}</p>
        )}
      </div>

      <div className="space-y-2 opacity-50 p-6">
        <p className="">...It&apos;s not free?</p>
        <p>How else am I supposed to acquire more unused devices to sit in my closet?</p>
      </div>


      <div className="flex justify-center">
        <Button variant="primary" onClick={() => auth.logout()}>
          Logout
        </Button>
      </div>
    </Layout>
  );
}
