"use client";

import * as React from "react";

export type ToggleProps = {
  checked?: boolean;
  onChange?: (checked: boolean) => void;
  disabled?: boolean;
  "aria-label"?: string;
  className?: string;
};

export function Toggle({
  checked = false,
  onChange,
  disabled = false,
  "aria-label": ariaLabel = "Toggle",
  className = "",
}: ToggleProps) {
  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    onChange?.(e.target.checked);
  };

  return (
    <label
      className={`
        relative inline-block h-6 w-11 shrink-0 cursor-pointer
        border-2 border-gameboy-darkest
        transition-colors duration-200 ease-out
        ${checked ? "bg-gameboy-darkest" : "bg-gameboy-light"}
        ${disabled ? "cursor-not-allowed opacity-60" : ""}
        ${className}
      `.trim().replace(/\s+/g, " ")}
    >
      <input
        type="checkbox"
        checked={checked}
        onChange={handleChange}
        disabled={disabled}
        aria-label={ariaLabel}
        className="peer sr-only"
      />
      <span
        className={`
          absolute top-1/2 left-0.5 h-5 w-5 -translate-y-1/2
          bg-gameboy-lightest border-2 border-gameboy-darkest
          transition-transform duration-200 ease-out
          peer-checked:translate-x-5
        `.trim().replace(/\s+/g, " ")}
      />
    </label>
  );
}
