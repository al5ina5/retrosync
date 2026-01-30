"use client";

import { useRouter } from "next/navigation";
import { useAuthContext } from "@/contexts/AuthContext";
import { DevicePairForm, DeviceList } from "@/components/devices";

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
    <div className="max-w-3xl mx-auto p-12 space-y-12">
      <DevicePairForm />
      <DeviceList />
    </div>
  );
}
