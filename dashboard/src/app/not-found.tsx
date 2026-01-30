"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import Layout from "@/components/ui/Layout";

const WITTY_LINES = [
  "This save file doesn't exist. Maybe it never saved?",
  "404: Level not found. Try another warp zone.",
  "You've wandered off the map. Turn back, hero.",
  "Game Over — wrong URL. Insert coin to continue.",
  "The princess is in another castle. (This one's empty.)",
  "404: Controller disconnected. Check your links.",
  "No continues left. This page has ended.",
  "You broke the fourth wall. And the fifth. And the URL.",
  "High score: 0. This page doesn't exist.",
  "Continue? No. (This page was never here.)",
  "Insert disk 2. (We only have disk 1.)",
  "404: Power-up not found. Try the home screen.",
  "You've discovered a glitch in the matrix. Or just a bad link.",
  "The dungeon is empty. Nothing to sync here.",
  "404: NPC not found. This page went off-script.",
  "Wrong warp pipe. Mario would be disappointed.",
  "This cartridge is corrupted. Or the URL is.",
  "404: No respawn point. Head back to base.",
  "You've found the void. It's not very interesting.",
  "Error: Zelda is not in this castle.",
  "404: Battery died. This page ran out of juice.",
  "The Konami code won't help here. Sorry.",
  "You've hit an invisible wall. Page does not exist.",
  "404: Level select failed. Choose another.",
];

function pickRandom<T>(arr: T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}

export default function NotFound() {
  const [line, setLine] = useState(WITTY_LINES[0]);

  useEffect(() => {
    setLine(pickRandom(WITTY_LINES));
  }, []);

  const btn =
    "border-4 border-gameboy-darkest bg-gameboy-darkest text-gameboy-lightest hover:bg-gameboy-lightest hover:text-gameboy-darkest px-6 py-3 whitespace-nowrap lg:text-xl transition-colors";

  return (
    <Layout>
      <div className="flex flex-col items-center justify-center min-h-[60vh] text-center space-y-8">
        <div className="space-y-2">
          <h1 className="text-6xl lg:text-8xl font-bold">404</h1>
          <p className="text-xl lg:text-2xl text-gameboy-dark max-w-md mx-auto">
            {line}
          </p>
        </div>
        <Link href="/" className={btn}>
          Return Home
        </Link>
      </div>
    </Layout>
  );
}
