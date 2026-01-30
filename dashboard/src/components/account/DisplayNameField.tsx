"use client";

import { useState } from "react";
import { useAuthContext } from "@/contexts/AuthContext";
import { InputWithButton } from "@/components/ui";

type DisplayNameFieldProps = {
  value: string;
  onChange: (value: string) => void;
};

/**
 * Display name flow: click Update → call API → done.
 */
export function DisplayNameField({ value, onChange }: DisplayNameFieldProps) {
  const auth = useAuthContext();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleUpdate = async () => {
    const trimmed = value.trim();
    if (!trimmed) {
      setError("Enter a display name");
      return;
    }
    if (!auth) return;
    setError(null);
    setLoading(true);
    try {
      const result = await auth.updateAccount({ name: trimmed });
      if (!result.success) {
        setError(result.error ?? "Update failed");
        return;
      }
      auth.refreshUser();
    } catch {
      setError("Update failed");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="space-y-1">
      <InputWithButton
        label="Display name"
        type="text"
        placeholder="Your name"
        value={value}
        onChange={(e) => {
          setError(null);
          onChange(e.target.value);
        }}
        onButtonClick={handleUpdate}
        buttonLabel="Update"
        loading={loading}
        disabled={value.trim() === (auth?.user?.name ?? "").trim()}
      />
      {error != null && (
        <p className="text-sm text-red-600" role="alert">
          {error}
        </p>
      )}
    </div>
  );
}
