"use client";

import * as React from "react";

export type ButtonVariant = "primary" | "secondary" | "ghost";

export type ButtonProps = {
  variant?: ButtonVariant;
  type?: "button" | "submit" | "reset";
  disabled?: boolean;
  className?: string;
  children: React.ReactNode;
} & React.ButtonHTMLAttributes<HTMLButtonElement>;

const variantStyles: Record<ButtonVariant, string> = {
  primary:
    "bg-gameboy-darkest text-gameboy-lightest hover:bg-gameboy-lightest hover:text-gameboy-darkest border-2 border-gameboy-darkest",
  secondary:
    "bg-transparent text-gameboy-darkest border-2 border-gameboy-darkest hover:bg-gameboy-darkest hover:text-gameboy-lightest",
  ghost:
    "bg-transparent text-gameboy-darkest hover:bg-gameboy-light border-transparent",
};

export function Button({
  variant = "primary",
  type = "button",
  disabled = false,
  className = "",
  children,
  ...rest
}: ButtonProps) {
  return (
    <button
      type={type}
      disabled={disabled}
      className={`
        inline-flex items-center justify-center
        px-4 py-2 whitespace-nowrap
        font-medium
        transition-colors duration-200 ease-out
        disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:bg-gameboy-darkest disabled:hover:text-gameboy-lightest
        ${variantStyles[variant]}
        ${className}
      `.trim().replace(/\s+/g, " ")}
      {...rest}
    >
      {children}
    </button>
  );
}
