"use client";

import React from "react";

/** Tailwind gameboy palette – keep in sync with tailwind.config.ts */
const GAMEBOY = {
  darkest: "#0f380f",
  dark: "#306230",
  light: "#8bac0f",
  lightest: "#9bbc0f",
} as const;

const SHADE_COUNT = 4;

/** Normalized 0–1 RGB for SVG feComponentTransfer */
function hexToNorm(hex: string): [number, number, number] {
  const r = parseInt(hex.slice(1, 3), 16) / 255;
  const g = parseInt(hex.slice(3, 5), 16) / 255;
  const b = parseInt(hex.slice(5, 7), 16) / 255;
  return [r, g, b];
}

/** Interpolate between two RGB tuples; t in [0, 1]. */
function lerp(
  a: [number, number, number],
  b: [number, number, number],
  t: number
): [number, number, number] {
  return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
}

const keyframes = [
  hexToNorm(GAMEBOY.darkest),
  hexToNorm(GAMEBOY.dark),
  hexToNorm(GAMEBOY.light),
  hexToNorm(GAMEBOY.lightest),
];

/** Build 14 shades by interpolating between the 4 keyframes (darkest → dark → light → lightest). */
function buildShades(): {
  discrete: string;
  r: string;
  g: string;
  b: string;
} {
  const discrete: number[] = [];
  const r: number[] = [];
  const g: number[] = [];
  const b: number[] = [];

  for (let i = 0; i < SHADE_COUNT; i++) {
    const t = i / (SHADE_COUNT - 1);
    discrete.push(t);

    // Map t to segment: 0–1/3, 1/3–2/3, 2/3–1
    let rgb: [number, number, number];
    if (t <= 1 / 3) {
      const u = t / (1 / 3);
      rgb = lerp(keyframes[0], keyframes[1], u);
    } else if (t <= 2 / 3) {
      const u = (t - 1 / 3) / (1 / 3);
      rgb = lerp(keyframes[1], keyframes[2], u);
    } else {
      const u = (t - 2 / 3) / (1 / 3);
      rgb = lerp(keyframes[2], keyframes[3], u);
    }
    r.push(rgb[0]);
    g.push(rgb[1]);
    b.push(rgb[2]);
  }

  return {
    discrete: discrete.join(" "),
    r: r.join(" "),
    g: g.join(" "),
    b: b.join(" "),
  };
}

const shades = buildShades();
const FILTER_ID = "gameboy-palette-filter";

/**
 * Wraps content with an SVG filter that maps any image to the dashboard’s
 * Game Boy (DMG) green palette (14 shades from the 4 Tailwind keyframes).
 * Use with img or any element.
 *
 * When fadeToOriginal is "right", the filtered layer is masked so it fades
 * from full opacity (left) to transparent (right), letting the original
 * colors show through on the right. Stack the original image underneath.
 *
 * Use fadeStart / fadeEnd (0–100) to control where the fade runs:
 * - fadeStart: % from left where full green ends (default 0)
 * - fadeEnd: % from left where mask is fully transparent (default 100)
 * Example: fadeStart={20} fadeEnd={80} → solid green 0–20%, fade 20–80%, original 80–100%
 */
export function GameboyFilter({
  children,
  className,
  fadeToOriginal,
  fadeStart = 0,
  fadeEnd = 100,
}: {
  children: React.ReactNode;
  className?: string;
  /** "right" = gradient mask so original colors leak through on the right */
  fadeToOriginal?: "right";
  /** % from left where full green ends; 0 = fade starts at left edge */
  fadeStart?: number;
  /** % from left where mask is fully transparent; 100 = fade ends at right edge */
  fadeEnd?: number;
}) {
  const gradient =
    fadeToOriginal === "right"
      ? `linear-gradient(to right, black ${fadeStart}%, transparent ${fadeEnd}%)`
      : undefined;

  const maskStyle =
    gradient
      ? {
        maskImage: gradient,
        maskSize: "cover",
        maskRepeat: "no-repeat",
        WebkitMaskImage: gradient,
        WebkitMaskSize: "cover",
        WebkitMaskRepeat: "no-repeat",
      }
      : undefined;

  return (
    <>
      <svg aria-hidden className="absolute size-0" focusable={false}>
        <defs>
          <filter id={FILTER_ID} colorInterpolationFilters="sRGB">
            {/* Grayscale (luminance) */}
            <feColorMatrix
              in="SourceGraphic"
              type="matrix"
              values="0.2126 0.7152 0.0722 0 0
                      0.2126 0.7152 0.0722 0 0
                      0.2126 0.7152 0.0722 0 0
                      0 0 0 1 0"
            />
            {/* Quantize to 14 levels */}
            <feComponentTransfer>
              <feFuncR type="discrete" tableValues={shades.discrete} />
              <feFuncG type="discrete" tableValues={shades.discrete} />
              <feFuncB type="discrete" tableValues={shades.discrete} />
            </feComponentTransfer>
            {/* Map to palette shades (interpolated from Tailwind gameboy colors) */}
            <feComponentTransfer>
              <feFuncR type="table" tableValues={shades.r} />
              <feFuncG type="table" tableValues={shades.g} />
              <feFuncB type="table" tableValues={shades.b} />
            </feComponentTransfer>
          </filter>
        </defs>
      </svg>
      <div
        className={className}
        style={{ filter: `url(#${FILTER_ID})`, ...maskStyle }}
      >
        {children}
      </div>
    </>
  );
}
