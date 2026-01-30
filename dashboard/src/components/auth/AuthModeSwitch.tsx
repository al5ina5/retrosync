"use client";

type AuthModeSwitchProps = {
  mode: "login" | "register";
  onSwitch: (mode: "login" | "register") => void;
};

export function AuthModeSwitch({ mode, onSwitch }: AuthModeSwitchProps) {
  return (
    <p className="text-center group">
      {mode === "login" ? (
        <>
          Don&apos;t have an account?<br />
          <button type="button" onClick={() => onSwitch("register")} className="underline group-hover:no-underline">
            Register
          </button>
        </>
      ) : (
        <>
          Already have an account?<br />
          <button type="button" onClick={() => onSwitch("login")} className="underline group-hover:no-underline">
            Sign In
          </button>
        </>
      )}
    </p>
  );
}
