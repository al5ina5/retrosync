"use client";

import { useState } from "react";
import { useAuthContext } from "@/contexts/AuthContext";
import { InputWithButton, Modal } from "@/components/ui";

type PasswordFieldProps = {
  value: string;
  onChange: (value: string) => void;
};

const MIN_PASSWORD_LENGTH = 8;

/**
 * Password flow: click Update → validate new password → if valid, modal with current password → API → done.
 */
export function PasswordField({ value, onChange }: PasswordFieldProps) {
  const auth = useAuthContext();
  const [loading, setLoading] = useState(false);
  const [newPasswordError, setNewPasswordError] = useState<string | null>(null);
  const [currentPasswordError, setCurrentPasswordError] = useState<string | null>(null);
  const [currentPasswordOpen, setCurrentPasswordOpen] = useState(false);
  const [currentPassword, setCurrentPassword] = useState("");

  const handleUpdateClick = () => {
    const trimmed = value.trim();
    setNewPasswordError(null);
    if (!trimmed) {
      setNewPasswordError("Enter a new password");
      return;
    }
    if (trimmed.length < MIN_PASSWORD_LENGTH) {
      setNewPasswordError("Password must be at least 8 characters");
      return;
    }
    setCurrentPassword("");
    setCurrentPasswordError(null);
    setCurrentPasswordOpen(true);
  };

  const handleCurrentPasswordSubmit = async () => {
    if (!currentPassword.trim() || !auth) return;
    setCurrentPasswordError(null);
    setLoading(true);
    try {
      const result = await auth.updateAccount({
        currentPassword,
        newPassword: value.trim(),
      });
      if (!result.success) {
        setCurrentPasswordError(result.error ?? "Update failed");
        return;
      }
      setCurrentPasswordOpen(false);
      setCurrentPassword("");
      onChange("");
      auth.refreshUser();
    } catch {
      setCurrentPasswordError("Update failed");
    } finally {
      setLoading(false);
    }
  };

  return (
    <>
      <Modal
        open={currentPasswordOpen}
        onClose={() => {
          if (!loading) {
            setCurrentPasswordOpen(false);
            setCurrentPassword("");
            setCurrentPasswordError(null);
          }
        }}
        title="Confirm current password"
      >
        <p className="text-gameboy-darkest mb-4">
          Enter your current password to complete the change.
        </p>
        <div className="space-y-1">
          <InputWithButton
            label="Current password"
            type="password"
            placeholder="••••••••"
            value={currentPassword}
            onChange={(e) => {
              setCurrentPasswordError(null);
              setCurrentPassword(e.target.value);
            }}
            onButtonClick={handleCurrentPasswordSubmit}
            buttonLabel="Confirm"
            loading={loading}
            loadingLabel="Updating…"
          />
          {currentPasswordError != null && (
            <p className="text-sm text-red-600" role="alert">
              {currentPasswordError}
            </p>
          )}
        </div>
      </Modal>

      <div className="space-y-1">
        <InputWithButton
          label="Password"
          type="password"
          placeholder="••••••••"
          value={value}
          onChange={(e) => {
            setNewPasswordError(null);
            onChange(e.target.value);
          }}
          onButtonClick={handleUpdateClick}
          buttonLabel="Update"
          loading={loading}
          disabled={!value.trim()}
        />
        {/* <p className="text-sm text-gameboy-dark opacity-70">
          At least 8 characters
        </p> */}
        {newPasswordError != null && (
          <p className="text-sm text-red-600" role="alert">
            {newPasswordError}
          </p>
        )}
      </div>
    </>
  );
}
