"use client";

import * as React from "react";

export type ToggleProps = {
  checked?: boolean;
  onChange?: (checked: boolean) => void;
  disabled?: boolean;
  "aria-label"?: string;
  /** Optional label; when set, the whole label + switch is clickable to toggle */
  label?: React.ReactNode;
  className?: string;
};

export function Toggle({
  checked = false,
  onChange,
  disabled = false,
  "aria-label": ariaLabel = "Toggle",
  label,
  className = "",
}: ToggleProps) {
  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    onChange?.(e.target.checked);
  };

  return (
    <label
      id={label != null ? "toggle-label" : undefined}
      className={`
        inline-flex items-center gap-2 cursor-pointer select-none
        ${disabled ? "cursor-not-allowed opacity-60" : ""}
        ${className}
      `.trim().replace(/\s+/g, " ")}
    >
      {label != null && <span>{label}</span>}
      <span className="relative inline-block h-3 w-6 shrink-0">
        <input
          type="checkbox"
          checked={checked}
          onChange={handleChange}
          disabled={disabled}
          aria-label={label == null ? ariaLabel : undefined}
          aria-labelledby={label != null ? "toggle-label" : undefined}
          className="peer sr-only"
        />
        <span
          className={`
            absolute inset-0 rounded-none border-2 border-gameboy-darkest
            transition-colors duration-200 ease-out
            bg-gameboy-light peer-checked:bg-gameboy-darkest
          `.trim().replace(/\s+/g, " ")}
        />
        <span
          className={`
            absolute top-1/2 left-0.5 h-2 w-2 -translate-y-1/2
            bg-gameboy-lightest border-2 border-gameboy-darkest
            transition-transform duration-200 ease-out
            peer-checked:translate-x-3
          `.trim().replace(/\s+/g, " ")}
        />
      </span>
    </label>
  );
}
