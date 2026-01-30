"use client";

import { useRouter } from "next/navigation";
import { useAuthContext } from "@/contexts/AuthContext";
import { DevicePairForm, DeviceList } from "@/components/devices";
import Layout from "@/components/ui/Layout";
import { Button } from "@/components/ui";

export default function DevicesPage() {
  const router = useRouter();
  const auth = useAuthContext();

  if (auth === null) return <div>Loading...</div>;
  const { isAuthenticated, isLoading: authLoading } = auth;

  if (authLoading) return <div>Loading...</div>;
  if (!isAuthenticated) {
    router.push("/auth");
    return null;
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
        <a className="border-4 border-gameboy-darkest bg-gameboy-darkest text-gameboy-lightest hover:bg-gameboy-lightest hover:text-gameboy-darkest px-6 py-3 whitespace-nowrap text-lg md:text-2xl">
          Upgrade for $6
        </a>
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
