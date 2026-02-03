"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuthContext } from "@/contexts/AuthContext";
import { AuthForm } from "@/components/auth";
import { useState } from "react";
import Layout from "@/components/ui/Layout";

export default function AuthPage() {
  const router = useRouter();
  const auth = useAuthContext();
  const [mode, setMode] = useState<"login" | "register">("register");
  const isAuthenticated = auth?.isAuthenticated ?? false;
  const isLoading = auth?.isLoading ?? true;

  useEffect(() => {
    if (!auth || isLoading || !isAuthenticated) return;
    let cancelled = false;

    const redirectAfterAuth = async () => {
      try {
        const token = localStorage.getItem("token");
        if (!token) {
          if (!cancelled) router.push("/onboard");
          return;
        }
        const res = await fetch("/api/devices", {
          headers: { Authorization: `Bearer ${token}` },
        });
        const data = await res.json();
        if (!cancelled) {
          if (res.ok && Array.isArray(data?.devices) && data.devices.length > 0) {
            router.push("/devices");
          } else {
            router.push("/onboard");
          }
        }
      } catch {
        if (!cancelled) router.push("/onboard");
      }
    };

    redirectAfterAuth();
    return () => {
      cancelled = true;
    };
  }, [auth, isAuthenticated, isLoading, router]);

  if (auth === null) return <div>Loading...</div>;

  if (isLoading) return <div>Loading...</div>;
  if (isAuthenticated) return <div>Loading...</div>;
  const isLoginMode = mode === "login";

  return (
    <Layout>
      {isLoginMode ? (
        <div className="space-y-6">
          <h1 className="text-4xl">Sign in to your account</h1>
          <button className="text-xl underline hover:no-underline" type="button" onClick={() => setMode("register")}>or sign up</button>
        </div>
      ) : (
        <div className="space-y-6">
          <h1 className="text-4xl">Sign up for a new account</h1>
          <button className="text-xl underline hover:no-underline" type="button" onClick={() => setMode("login")}>or sign in</button>
        </div>
      )}
      <AuthForm mode={mode} setMode={setMode} />
    </Layout>
  );
}
