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
      Shake it to the max.

      <div className="flex justify-center">
        <Button variant="primary" onClick={() => auth.logout()}>
          Logout
        </Button>
      </div>
    </Layout>
  );
}
