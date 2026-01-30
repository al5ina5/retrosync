"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/hooks";

export function AuthForm({ mode, setMode }: { mode: "login" | "register", setMode: (mode: "login" | "register") => void }) {
  const router = useRouter();
  const { login, register } = useAuth({ redirectOnUnauthenticated: false });

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setSubmitting(true);
    const result =
      mode === "login" ? await login(email, password) : await register(email, password);
    setSubmitting(false);
    if (result.success) router.push("/");
    else setError(result.error || "Something went wrong");
  };

  const handleSwitchMode = () => {
    setError("");
    setMode(mode === "login" ? "register" : "login");
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      <div className="space-y-2">
        <label>Email</label>
        <input
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          className="w-full placeholder:text-gameboy-lightest text-3xl outline-none bg-gameboy-light py-2 px-4"
          placeholder="you@example.com"
          required
        />
      </div>
      <div>
        <label>Password</label>
        <input
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          className="w-full placeholder:text-gameboy-lightest text-3xl outline-none bg-gameboy-light py-2 px-4"
          placeholder="********"
          required
        />
      </div>
      {error && <p>{error}</p>}
      <div className="flex justify-between gap-2">
        <button
          type="button"
          onClick={handleSwitchMode}
          disabled={submitting}
          className="border-2 border-gameboy-darkest text-gameboy-darkest py-2 px-4 hover:opacity-80 disabled:opacity-50"
        >
          {mode === "login" ? "Register" : "Sign In"}
        </button>
        <button
          type="submit"
          disabled={submitting}
          className="bg-gameboy-darkest text-gameboy-lightest py-2 px-4"
        >
          {submitting ? "Loading..." : mode === "login" ? "Sign In" : "Register"}
        </button>
      </div>
    </form>
  );
}
