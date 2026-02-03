"use client";

import Layout from "@/components/ui/Layout";

export default function HowItWorksPage() {
  return (
    <Layout>
      <div className="space-y-6 text-center">
        <p className="text-xs uppercase tracking-[0.3em] text-gameboy-darkest/70">About</p>
        <h1 className="text-4xl lg:text-6xl leading-tight">How RetroSync Works</h1>
        <p className="text-lg lg:text-2xl text-gameboy-darkest/80 max-w-2xl mx-auto">
          Built by an indie dev who lost one too many saves and decided “never again.”
        </p>
      </div>

      <div className="space-y-16">
        <section className="border-2 border-gameboy-darkest bg-gameboy-lightest/60 p-6 lg:p-10 space-y-6">
          <h2 className="text-2xl lg:text-3xl border-b-2 border-gameboy-darkest pb-3">The basics</h2>
          <p className="text-base lg:text-xl">
            RetroSync keeps your game saves in sync across your retro handhelds and your computer. No
            spreadsheets. No “which device was last?” panic. Just one source of truth.
          </p>
          <div className="grid gap-4 sm:grid-cols-3">
            <div className="border-2 border-gameboy-darkest p-4">
              <p className="text-xs uppercase tracking-[0.25em] text-gameboy-darkest/70">Step 1</p>
              <p className="text-lg lg:text-xl mt-2">Install the client</p>
            </div>
            <div className="border-2 border-gameboy-darkest p-4">
              <p className="text-xs uppercase tracking-[0.25em] text-gameboy-darkest/70">Step 2</p>
              <p className="text-lg lg:text-xl mt-2">Pair with a short code</p>
            </div>
            <div className="border-2 border-gameboy-darkest p-4">
              <p className="text-xs uppercase tracking-[0.25em] text-gameboy-darkest/70">Step 3</p>
              <p className="text-lg lg:text-xl mt-2">Play anywhere</p>
            </div>
          </div>
        </section>

        <section className="border-2 border-gameboy-darkest bg-gameboy-lightest/60 p-6 lg:p-10 space-y-6">
          <h2 className="text-2xl lg:text-3xl border-b-2 border-gameboy-darkest pb-3">Why I built it</h2>
          <p className="text-base lg:text-xl">
            I’m an indie dev with a cabinet of handhelds and a graveyard of overwritten saves.
            RetroSync started as a weekend fix and became the “please don’t make me replay that boss”
            button.
          </p>
          <p className="text-base lg:text-xl">
            It’s the tiny, boring glue between devices that keeps your progress safe — the kind of
            tool you stop thinking about once it works.
          </p>
        </section>

        <section className="border-2 border-gameboy-darkest bg-gameboy-lightest/60 p-6 lg:p-10 space-y-6">
          <h2 className="text-2xl lg:text-3xl border-b-2 border-gameboy-darkest pb-3">Pricing</h2>
          <div className="grid gap-6 md:grid-cols-2">
            <div className="border-2 border-gameboy-darkest p-5 space-y-3">
              <p className="text-xs uppercase tracking-[0.25em] text-gameboy-darkest/70">Free</p>
              <p className="text-lg lg:text-2xl">Core syncing</p>
              <p className="text-sm lg:text-base text-gameboy-darkest/80">
                Sensible limits for casual play. Pair devices, sync saves, keep moving.
              </p>
            </div>
            <div className="border-2 border-gameboy-darkest p-5 space-y-3">
              <p className="text-xs uppercase tracking-[0.25em] text-gameboy-darkest/70">Pro</p>
              <p className="text-lg lg:text-2xl">$6 / month</p>
              <p className="text-sm lg:text-base text-gameboy-darkest/80">
                Remove free-tier limits and keep every device in lockstep.
              </p>
            </div>
          </div>
        </section>

        <div className="flex flex-wrap justify-center gap-4 pt-4">
          <a
            href="/auth"
            className="border-4 border-gameboy-darkest bg-gameboy-darkest text-gameboy-lightest hover:bg-gameboy-lightest hover:text-gameboy-darkest px-8 py-4 whitespace-nowrap text-lg"
          >
            Get started
          </a>
          <a href="/download" className="underline hover:no-underline text-base lg:text-lg">
            Download the client
          </a>
        </div>
      </div>
    </Layout>
  );
}
