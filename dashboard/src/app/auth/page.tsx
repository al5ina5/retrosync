"use client";

import { useRouter } from "next/navigation";
import { useAuthContext } from "@/contexts/AuthContext";
import { AuthForm } from "@/components/auth";
import { useState } from "react";

export default function AuthPage() {
  const router = useRouter();
  const auth = useAuthContext();
  const [mode, setMode] = useState<"login" | "register">("register");

  if (auth === null) return <div>Loading...</div>;
  const { isAuthenticated, isLoading } = auth;

  if (isLoading) return <div>Loading...</div>;
  if (isAuthenticated) {
    router.push("/");
    return null;
  }
  const isLoginMode = mode === "login";

  return (
    <div className="max-w-xl mx-auto p-12 pt-24 space-y-24 text-center">
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
    </div >
  );
}
