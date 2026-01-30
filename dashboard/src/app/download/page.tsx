"use client";

import Layout from "@/components/ui/Layout";
import Link from "next/link";

export default function DownloadPage() {
  return (
    <Layout>
      <div className="space-y-6 text-center">
        <h1 className="text-3xl lg:text-5xl">Download the client</h1>
        <p className="text-lg lg:text-xl">
          Get the RetroSync app for your device to sync saves from your handheld.
        </p>
      </div>

      <section className="space-y-4">
        <h2 className="text-xl font-medium border-b-2 border-gameboy-darkest pb-2">
          For your device
        </h2>
        <p className="text-gameboy-dark">
          The client runs on retro handhelds (e.g. Miyoo, Anbernic). Pick your OS below.
        </p>

        <div className="grid gap-4 sm:grid-cols-2">
          <div className="border-2 border-gameboy-darkest bg-gameboy-lightest p-4 rounded-none">
            <h3 className="font-medium text-lg mb-2">muOS</h3>
            <p className="text-sm text-gameboy-dark mb-3">
              Install the RetroSync client on devices running muOS.
            </p>
            <a
              href="#"
              className="inline-block border-2 border-gameboy-darkest bg-gameboy-darkest text-gameboy-lightest hover:bg-gameboy-lightest hover:text-gameboy-darkest px-4 py-2 text-sm"
            >
              Get for muOS
            </a>
          </div>
          <div className="border-2 border-gameboy-darkest bg-gameboy-lightest p-4 rounded-none">
            <h3 className="font-medium text-lg mb-2">spruceOS</h3>
            <p className="text-sm text-gameboy-dark mb-3">
              Install the RetroSync client on devices running spruceOS.
            </p>
            <a
              href="#"
              className="inline-block border-2 border-gameboy-darkest bg-gameboy-darkest text-gameboy-lightest hover:bg-gameboy-lightest hover:text-gameboy-darkest px-4 py-2 text-sm"
            >
              Get for spruceOS
            </a>
          </div>
        </div>

        <div className="border-2 border-gameboy-dark p-4 mt-6">
          <p className="text-sm">
            <strong>Building from source?</strong> From the repo root:{" "}
            <code className="bg-gameboy-dark text-gameboy-lightest px-1">npm run client:build</code> then{" "}
            <code className="bg-gameboy-dark text-gameboy-lightest px-1">npm run client:deploy</code>.
          </p>
        </div>
      </section>

      <div className="text-center pt-4">
        <Link
          href="/"
          className="text-gameboy-dark underline hover:no-underline"
        >
          ← Back to home
        </Link>
      </div>
    </Layout>
  );
}
