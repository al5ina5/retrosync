import type { Config } from "tailwindcss";

/** Classic Game Boy (DMG) 4-shade LCD green – keep in sync with src/lib/theme/gameboy.ts */
const gameboy = {
  darkest: "#0f380f",
  dark: "#306230",
  light: "#8bac0f",
  lightest: "#9bbc0f",
};

const config: Config = {
  content: [
    "./src/pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/components/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        gameboy,
      },
      fontFamily: {
        gameboy: ['"Early GameBoy"', "monospace"],
        minecraft: ['"Minecraft"', "monospace"],
      },
    },
  },
  plugins: [],
};
export default config;
