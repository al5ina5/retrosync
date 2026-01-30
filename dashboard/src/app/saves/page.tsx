"use client";

import { useRouter } from "next/navigation";
import { useAuthContext } from "@/contexts/AuthContext";
import { useSavesContext } from "@/contexts/SavesContext";
import { SaveList } from "@/components/saves";

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
    <div className="max-w-3xl mx-auto p-12 space-y-12">
      {/* <h1>Saves ({count})</h1> */}
      <SaveList />
    </div>
  );
}
