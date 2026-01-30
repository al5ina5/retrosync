"use client";

import { useRouter } from "next/navigation";
import { useAuthContext } from "@/contexts/AuthContext";
import { useSavesContext } from "@/contexts/SavesContext";
import { SaveList } from "@/components/saves";
import Layout from "@/components/ui/Layout";

export default function SavesPage() {
  const router = useRouter();
  const auth = useAuthContext();
  const saves = useSavesContext();

  if (auth === null) return <div>Loading...</div>;
  const { isAuthenticated, isLoading: authLoading } = auth;

  if (authLoading) return <div>Loading...</div>;
  if (!isAuthenticated) {
    router.push("/auth");
    return null;
  }

  const count = saves?.count ?? 0;

  return (
    <Layout>
      <SaveList />
    </Layout>
  );
}
