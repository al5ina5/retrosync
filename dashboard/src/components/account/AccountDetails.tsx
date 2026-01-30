"use client";

import { useState, useEffect } from "react";
import { useAuthContext } from "@/contexts/AuthContext";
import {
  DisplayNameField,
  EmailField,
  PasswordField,
} from "@/components/account";

export function AccountDetails() {
  const auth = useAuthContext();
  const [email, setEmail] = useState("");
  const [name, setName] = useState("");
  const [password, setPassword] = useState("");

  useEffect(() => {
    if (auth?.user?.email != null) setEmail(auth.user.email);
    if (auth?.user?.name != null) setName(auth.user.name ?? "");
  }, [auth?.user?.email, auth?.user?.name]);

  const memberSince =
    auth?.user?.createdAt != null
      ? new Date(auth.user.createdAt).toLocaleDateString(undefined, {
        year: "numeric",
        month: "long",
      })
      : null;

  return (
    <div className="space-y-6">
      <p className="text-2xl">Account</p>
      <p>Manage and make changes to your account details here.</p>
      {memberSince != null && (
        <p className="text-sm text-gameboy-dark opacity-80">Member since {memberSince}</p>
      )}
      <div className="space-y-4">
        <DisplayNameField value={name} onChange={setName} />
        <EmailField value={email} onChange={setEmail} />
        <PasswordField value={password} onChange={setPassword} />
      </div>
    </div>
  );
}
