"use client";

/**
 * Generic confirmation screen: message + confirm/cancel options.
 * Use inside ClientViewport (client mockup), in a modal, or inline for settings (unpair, delete, etc.).
 */
export type ConfirmScreenProps = {
  /** Main prompt (e.g. "Are you sure you want to unpair this device?") */
  message: string;
  /** Label for confirm action (e.g. "Yes", "Unpair") */
  confirmLabel?: string;
  /** Label for cancel action (e.g. "No", "Cancel") */
  cancelLabel?: string;
  /** Called when user confirms */
  onConfirm?: () => void;
  /** Called when user cancels */
  onCancel?: () => void;
  /** Optional subtitle below options (e.g. device name) */
  subtitle?: React.ReactNode;
  /** For static mockup: which option appears selected. Omit for interactive buttons. */
  selectedOption?: "confirm" | "cancel";
  /** Visual variant (e.g. danger for unpair/delete) */
  variant?: "default" | "danger";
  /** Extra class for the container */
  className?: string;
};

const selectedRowClass = "bg-gameboy-darkest text-gameboy-lightest px-4 py-2";
const unselectedRowClass = "px-4 py-2";

export function ConfirmScreen({
  message,
  confirmLabel = "Yes",
  cancelLabel = "No",
  onConfirm,
  onCancel,
  subtitle,
  selectedOption,
  variant = "default",
  className = "",
}: ConfirmScreenProps) {
  const isInteractive = selectedOption == null;
  const messageClass =
    variant === "danger"
      ? "text-gameboy-darkest"
      : "text-gameboy-darkest";

  return (
    <div
      className={`flex flex-col space-y-12 items-center justify-center text-center ${className}`}
    >
      <p className={`text-lg max-w-md ${messageClass}`}>{message}</p>

      <div className="flex flex-col space-y-1 items-center">
        {isInteractive ? (
          <>
            <button
              type="button"
              onClick={onConfirm}
              className="border-2 border-gameboy-darkest px-4 py-2 hover:bg-gameboy-darkest hover:text-gameboy-lightest transition-colors"
            >
              {confirmLabel}
            </button>
            <button
              type="button"
              onClick={onCancel}
              className="border-2 border-gameboy-darkest bg-gameboy-darkest text-gameboy-lightest px-4 py-2 hover:bg-gameboy-dark hover:text-gameboy-lightest transition-colors"
            >
              {cancelLabel}
            </button>
          </>
        ) : (
          <>
            <p className={selectedOption === "confirm" ? selectedRowClass : unselectedRowClass}>
              {confirmLabel}
            </p>
            <p className={selectedOption === "cancel" ? selectedRowClass : unselectedRowClass}>
              {cancelLabel}
            </p>
          </>
        )}
      </div>

      {subtitle != null && (
        <p className="opacity-50 text-sm">{subtitle}</p>
      )}
    </div>
  );
}
