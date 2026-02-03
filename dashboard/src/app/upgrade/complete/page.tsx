"use client";

import Link from "next/link";
import { Suspense } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useEffect, useState } from "react";
import { useAuthContext } from "@/contexts/AuthContext";
import Layout from "@/components/ui/Layout";

function UpgradeCompleteContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const auth = useAuthContext();
  const [verified, setVerified] = useState<boolean | null>(null);

  const sessionId = searchParams.get("session_id");

  useEffect(() => {
    if (auth === null) return;
    const { isAuthenticated, isLoading: authLoading, getToken } = auth;
    if (authLoading) return;
    if (!isAuthenticated) {
      router.replace("/auth");
      return;
    }
    if (!sessionId) {
      router.replace("/upgrade");
      return;
    }
    const token = getToken();
    if (!token) {
      router.replace("/upgrade");
      return;
    }
    fetch(`/api/upgrade/verify?session_id=${encodeURIComponent(sessionId)}`, {
      headers: { Authorization: `Bearer ${token}` },
    })
      .then((res) => res.json())
      .then((json) => {
        if (json.success && json.data?.ok) {
          setVerified(true);
        } else {
          router.replace("/upgrade");
        }
      })
      .catch(() => router.replace("/upgrade"));
  }, [auth, sessionId, router]);

  if (auth === null) return <div>Loading...</div>;
  if (!auth.isAuthenticated || verified === null) return <div>Loading...</div>;
  if (!sessionId) return null;

  return (
    <Layout>
      <div className="space-y-6">
        <h1 className="text-2xl lg:text-3xl">
          You have been successfully upgraded. HOORAH!
        </h1>
        <p className="lg:text-xl">
          Now, you&apos;ll need to pair your devices to start syncing your saves. Need help? We&apos;re available to help you out.
        </p>
      </div>

      <div>
        <Link href="/devices" className="border-4 border-gameboy-darkest bg-gameboy-darkest text-gameboy-lightest hover:bg-gameboy-lightest hover:text-gameboy-darkest px-6 py-3 whitespace-nowrap text-lg md:text-2xl">
          Sync a Device
        </Link>
      </div>
    </Layout>
  );
}

export default function UpgradeCompletePage() {
  return (
    <Suspense fallback={<div>Loading...</div>}>
      <UpgradeCompleteContent />
    </Suspense>
  );
}
