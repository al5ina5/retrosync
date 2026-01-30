"use client";

import { Portal } from "./Portal";

type ModalProps = {
  /** Whether the modal is visible. */
  open: boolean;
  /** Called when the user closes the modal (e.g. backdrop click or close button). */
  onClose: () => void;
  /** Modal content. */
  children: React.ReactNode;
  /** Optional title. */
  title?: string;
};

/**
 * Simple modal rendered at document.body via Portal. Backdrop click closes it.
 */
export function Modal({ open, onClose, title, children }: ModalProps) {
  if (!open) return null;

  return (
    <Portal>
      <div
        className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50"
        onClick={onClose}
        role="dialog"
        aria-modal="true"
        aria-labelledby={title ? "modal-title" : undefined}
      >
        <div
          className="bg-gameboy-lightest border-2 border-gameboy-darkest shadow-xl max-w-md w-full max-h-[90vh] overflow-auto"
          onClick={(e) => e.stopPropagation()}
        >
          {title != null && (
            <div className="flex items-center justify-between border-b-2 border-gameboy-darkest px-4 py-3">
              <h2 id="modal-title" className="text-lg font-medium text-gameboy-darkest">
                {title}
              </h2>
              <button
                type="button"
                onClick={onClose}
                className="text-gameboy-darkest hover:bg-gameboy-dark hover:text-gameboy-lightest p-1 rounded transition-colors"
                aria-label="Close"
              >
                ×
              </button>
            </div>
          )}
          <div className="p-4 text-gameboy-darkest">{children}</div>
        </div>
      </div>
    </Portal>
  );
}
