"use client";

import { Icon, type IconProps } from "@iconify/react";

type PixelIconProps = Omit<IconProps, "icon"> & {
  icon: IconProps["icon"];
};

/**
 * Pixel-art icon (Pixelarticons) with Game Boy–friendly defaults.
 * Use with icons from `@/components/ui/pixel-icons` or any @iconify-icons/pixelarticons icon.
 * Icons use currentColor so they inherit text color (e.g. text-gameboy-dark).
 */
export function PixelIcon({
  icon,
  width = 24,
  height = 24,
  className,
  ...rest
}: PixelIconProps) {
  return (
    <Icon
      icon={icon}
      width={width}
      height={height}
      className={className}
      style={{ imageRendering: "crisp-edges" }}
      {...rest}
    />
  );
}
