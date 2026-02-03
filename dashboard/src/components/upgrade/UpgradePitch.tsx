"use client";

export function UpgradePitch() {
  return (
    <div className="border-2 border-gameboy-darkest p-6 md:p-8 space-y-6 bg-gameboy-lightest">
      <div className="space-y-4">
        <p className="text-2xl lg:text-3xl">
          It&apos;s time to get you into the club.
        </p>
        <p className="lg:text-xl">
          You are stuck in free account hell. Please upgrade to a paid account to
          access all of RetroSync&apos;s premium features and join the secret
          community.
        </p>
      </div>

      <div className="space-y-2 lg:text-xl">
        <p>- Unlimited devices</p>
        <p>- Unlimited saves</p>
        <p>- Unlimited games</p>
        <p>- Unlimited syncs</p>
        <p>- Only one plan</p>
        <p>- No buillshit pricing tiers</p>
        <p>- What you see is what you get</p>
      </div>
    </div>
  );
}
