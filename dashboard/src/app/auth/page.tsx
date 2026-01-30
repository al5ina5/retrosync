"use client";

import { useRouter } from "next/navigation";
import { useAuthContext } from "@/contexts/AuthContext";
import { AuthForm } from "@/components/auth";
import { useState } from "react";

export default function AuthPage() {
  const router = useRouter();
  const auth = useAuthContext();
  const [mode, setMode] = useState<"login" | "register">("login");

  if (auth === null) return <div>Loading...</div>;
  const { isAuthenticated, isLoading } = auth;

  if (isLoading) return <div>Loading...</div>;
  if (isAuthenticated) {
    router.push("/");
    return null;
  }
  const isLoginMode = mode === "login";

  return (
    <div className="max-w-xl mx-auto p-12 space-y-12">
      {isLoginMode ? (
        <h1 className="text-6xl">Sign in to your account</h1>
      ) : (
        <h1 className="text-6xl">Sign up for a new account</h1>
      )}
      <AuthForm mode={mode} setMode={setMode} />
    </div>
  );
}
