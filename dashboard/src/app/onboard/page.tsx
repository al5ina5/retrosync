"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { useAuthContext } from "@/contexts/AuthContext";
import { DevicePairForm } from "@/components/devices";
import Downloads from "@/components/devices/Downloads";
import Layout from "@/components/ui/Layout";
import { Button } from "@/components/ui";
import { UpgradePitch } from "@/components/upgrade";
import { useUpgradeCheckout } from "@/hooks";

export default function OnboardPage() {
  const router = useRouter();
  const auth = useAuthContext();
  const [step, setStep] = useState(0);
  const totalSteps = 3;
  const {
    startCheckout,
    isLoading: checkoutLoading,
    error: checkoutError,
  } = useUpgradeCheckout({ getToken: auth?.getToken ?? (() => null) });

  if (auth === null) return <div>Loading...</div>;
  const { isAuthenticated, isLoading: authLoading } = auth;

  if (authLoading) return <div>Loading...</div>;
  if (!isAuthenticated) {
    router.push("/auth");
    return null;
  }

  const goNext = () => {
    if (step < totalSteps - 1) {
      setStep(step + 1);
      return;
    }
    if (!checkoutLoading) startCheckout();
  };

  const goBack = () => {
    if (step > 0) setStep(step - 1);
  };

  return (
    <Layout>
      <div className="space-y-2">
        <h1 className="text-3xl lg:text-4xl">Get set up</h1>
        <p className="lg:text-xl">Three quick steps. You can skip anytime.</p>
        <p className="text-sm uppercase tracking-wide text-gameboy-darkest/70">
          Step {step + 1} of {totalSteps}
        </p>
      </div>

      {step === 0 && (
        <div className="space-y-6">
          <div className="flex items-center gap-3 text-sm uppercase tracking-wide">
            <span className="border-2 border-gameboy-darkest px-2 py-1">Step 1</span>
            <span>Download</span>
          </div>
          <Downloads />
        </div>
      )}

      {step === 1 && (
        <div className="space-y-6">
          <div className="flex items-center gap-3 text-sm uppercase tracking-wide">
            <span className="border-2 border-gameboy-darkest px-2 py-1">Step 2</span>
            <span>Pair</span>
          </div>
          <p className="text-gameboy-darkest/80 lg:text-lg">
            Open RetroSync on any device, then enter the pairing code it shows.
          </p>
          <DevicePairForm />
        </div>
      )}

      {step === 2 && (
        <div className="space-y-6">
          <div className="flex items-center gap-3 text-sm uppercase tracking-wide">
            <span className="border-2 border-gameboy-darkest px-2 py-1">Step 3</span>
            <span>Upgrade</span>
          </div>
          <UpgradePitch />
        </div>
      )}

      <div className="flex flex-wrap items-center gap-4">
        <Button variant="secondary" onClick={goBack} disabled={step === 0}>
          Back
        </Button>
        <Button variant="primary" onClick={goNext} disabled={checkoutLoading}>
          {step === totalSteps - 1
            ? checkoutLoading
              ? "Redirecting..."
              : "Upgrade to PRO"
            : "Next"}
        </Button>
        <a href="/devices" className="text-sm underline hover:no-underline">
          Pass. Free-tier hard mode.
        </a>
      </div>
      {step === totalSteps - 1 && checkoutError && (
        <p className="text-sm text-red-600 dark:text-red-400">{checkoutError}</p>
      )}
    </Layout>
  );
}
