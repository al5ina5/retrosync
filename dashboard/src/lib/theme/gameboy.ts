/**
 * Classic Game Boy (DMG) 4-shade LCD green palette.
 * Use via Tailwind: bg-gameboy-darkest, text-gameboy-light, etc.
 */
export const gameboy = {
  darkest: "#0f380f",
  dark: "#306230",
  light: "#8bac0f",
  lightest: "#9bbc0f",
} as const;

export type GameboyPalette = keyof typeof gameboy;
