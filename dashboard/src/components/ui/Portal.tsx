"use client";

import { createPortal } from "react-dom";

type PortalProps = {
  /** Content to render at the top level of the document (e.g. modals, overlays). */
  children: React.ReactNode;
  /** DOM node to mount into. Defaults to document.body. */
  container?: HTMLElement | null;
};

/**
 * Renders children into a DOM node outside the normal React tree (e.g. document.body).
 * Use for modals, overlays, and tooltips so they aren't clipped by parent overflow/stacking context.
 */
export function Portal({ children, container }: PortalProps) {
  if (typeof document === "undefined") {
    return null;
  }
  const target = container ?? document.body;
  return createPortal(children, target);
}
