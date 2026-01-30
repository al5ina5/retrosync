"use client";

import { useState } from "react";
import { useAuthContext } from "@/contexts/AuthContext";
import { ConfirmScreen, InputWithButton, Modal } from "@/components/ui";

type EmailFieldProps = {
  value: string;
  onChange: (value: string) => void;
};

/**
 * Email flow: click Update → "Are you sure? This will change your login details" → confirm → API → done.
 */
export function EmailField({ value, onChange }: EmailFieldProps) {
  const auth = useAuthContext();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [confirmOpen, setConfirmOpen] = useState(false);

  const handleConfirm = async () => {
    setConfirmOpen(false);
    if (!auth) return;
    setError(null);
    setLoading(true);
    try {
      const result = await auth.updateAccount({ email: value.trim() });
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
    <>
      <Modal
        open={confirmOpen}
        onClose={() => setConfirmOpen(false)}
        title="Change email"
      >
        <ConfirmScreen
          message="Are you sure? This will change your login details."
          confirmLabel="Yes, change email"
          cancelLabel="Cancel"
          onConfirm={handleConfirm}
          onCancel={() => setConfirmOpen(false)}
        />
      </Modal>
      <div className="space-y-1">
        <InputWithButton
          label="Email"
          type="email"
          placeholder="you@example.com"
          value={value}
          onChange={(e) => {
            setError(null);
            onChange(e.target.value);
          }}
          onButtonClick={() => setConfirmOpen(true)}
          buttonLabel="Update"
          loading={loading}
          disabled={value.trim() === (auth?.user?.email ?? "").trim()}
        />
        {error != null && (
          <p className="text-sm text-red-600" role="alert">
            {error}
          </p>
        )}
      </div>
    </>
  );
}
