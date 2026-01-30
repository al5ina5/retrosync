"use client";

import * as React from "react";
import { Button } from "./Button";

const inputClass =
  "min-w-0 flex-1 px-4 py-2 bg-gameboy-light placeholder:text-gameboy-lightest outline-none rounded-l-none";

export type InputWithButtonProps = {
  label?: string;
  buttonLabel?: string;
  /** Shown on the button when loading is true. */
  loadingLabel?: string;
  onButtonClick?: () => void;
  disabled?: boolean;
  /** When true, button is disabled and shows loadingLabel. */
  loading?: boolean;
  inputClassName?: string;
  containerClassName?: string;
} & Omit<React.InputHTMLAttributes<HTMLInputElement>, "className">;

export function InputWithButton({
  label,
  buttonLabel = "Update",
  loadingLabel = "Updating…",
  onButtonClick,
  disabled = false,
  loading = false,
  inputClassName = "",
  containerClassName = "",
  id: idProp,
  ...inputProps
}: InputWithButtonProps) {
  const id = idProp ?? React.useId();
  const buttonDisabled = disabled || loading;

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!buttonDisabled) onButtonClick?.();
  };

  return (
    <form
      onSubmit={handleSubmit}
      className={`space-y-2 ${containerClassName}`}
    >
      <div>
        {label != null && (
          <label htmlFor={id} className="block text-sm font-medium">
            {label}
          </label>
        )}

      </div>
      <div className="flex min-w-0 gap-0">
        <input
          id={id}
          className={`${inputClass} ${inputClassName}`}
          disabled={loading}
          {...inputProps}
        />
        <Button type="submit" disabled={buttonDisabled} className="shrink-0">
          {loading ? loadingLabel : buttonLabel}
        </Button>
      </div>
    </form>
  );
}
