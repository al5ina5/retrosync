"use client";

import { useRouter } from "next/navigation";
import { useAuthContext } from "@/contexts/AuthContext";
import { Subscription, AccountDetails, DangerZone } from "@/components/account";
import Layout from "@/components/ui/Layout";
import { Button } from "@/components/ui";

export default function AccountPage() {
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
      <div className="space-y-24">
        <AccountDetails />

        <Subscription />

        <DangerZone />
      </div>

      <div className="flex justify-center">
        <Button variant="primary" onClick={() => auth.logout()}>
          Logout
        </Button>
      </div>
    </Layout>
  );
}
