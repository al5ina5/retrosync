"use client";

import Link from "next/link";
import { useAuthContext } from "@/contexts/AuthContext";
import { useStripePortal } from "@/hooks";
import { Button } from "@/components/ui";

export function Subscription() {
  const auth = useAuthContext();
  const { openPortal, isLoading: portalLoading } = useStripePortal({
    getToken: () => auth?.getToken() ?? null,
  });

  const tier = auth?.user?.subscriptionTier ?? null;
  const loading = auth?.isLoading ?? true;

  if (loading || (auth?.isAuthenticated && tier === null)) {
    return (
      <div className="space-y-6">
        <p className="text-2xl">Subscription</p>
        <p>Loading…</p>
      </div>
    );
  }

  const isPaid = tier === "paid";

  return (
    <div className="space-y-6">
      <p className="text-2xl">Subscription</p>
      {isPaid ? (
        <>
          <p>
            You&apos;re on the Pro plan. You can manage your subscription in the Stripe customer portal.
          </p>
          <Button
            variant="secondary"
            onClick={openPortal}
            disabled={portalLoading}
          >
            {portalLoading ? "Opening…" : "Manage Subscription"}
          </Button>
        </>
      ) : (
        <>
          <p>
            You are currently on the free plan. Upgrade to the paid plan to get unlimited devices and saves.
          </p>
          <Link href="/upgrade">
            <Button variant="primary">Upgrade</Button>
          </Link>
        </>
      )}
    </div>
  );
}
