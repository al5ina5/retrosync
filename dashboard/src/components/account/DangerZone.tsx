"use client";

import { useState } from "react";
import { useAuthContext } from "@/contexts/AuthContext";
import { Modal, InputWithButton } from "@/components/ui";

export function DangerZone() {
  const auth = useAuthContext();
  const [modalOpen, setModalOpen] = useState(false);
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleDelete = async () => {
    if (!password.trim() || !auth) return;
    setError(null);
    setLoading(true);
    try {
      const result = await auth.deleteAccount(password.trim());
      if (result.success) {
        auth.logout();
      } else {
        setError(result.error ?? "Failed to delete account");
      }
    } catch {
      setError("Failed to delete account");
    } finally {
      setLoading(false);
    }
  };

  return (
    <>
      <Modal
        open={modalOpen}
        onClose={() => {
          if (!loading) {
            setModalOpen(false);
            setPassword("");
            setError(null);
          }
        }}
        title="Delete account"
      >
        <p className="text-gameboy-darkest mb-4">
          This will permanently delete your account, all devices, and all save data.
          This cannot be undone.
        </p>
        <p className="text-gameboy-darkest mb-4">
          Enter your password to confirm.
        </p>
        <div className="space-y-1">
          <InputWithButton
            label="Password"
            type="password"
            placeholder="••••••••"
            value={password}
            onChange={(e) => {
              setError(null);
              setPassword(e.target.value);
            }}
            onButtonClick={handleDelete}
            buttonLabel="Delete account"
            loading={loading}
            loadingLabel="Deleting…"
            disabled={!password.trim()}
          />
          {error != null && (
            <p className="text-sm text-red-600" role="alert">
              {error}
            </p>
          )}
        </div>
      </Modal>

      <div className="space-y-6">
        <p className="text-2xl text-red-600">Danger zone</p>
        <p>
          Permanently delete your account and all associated data. This action
          cannot be undone.
        </p>
        <button
          type="button"
          onClick={() => setModalOpen(true)}
          className="border-2 border-red-600 text-red-600 px-4 py-2 hover:bg-red-600 hover:text-white transition-colors"
        >
          Delete account
        </button>
      </div>
    </>
  );
}
