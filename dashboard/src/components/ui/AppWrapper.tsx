import { AppNav } from "../AppNav";
import { GameboyFilter } from "./GameboyFilter";

export default function AppWrapper({ children, disabled = true }: { children: React.ReactNode, disabled?: boolean }) {
    if (disabled) return children
    return (
        <div className="flex">
            <div className="w-full 3xl:w-1/2">
                {children}
            </div>
            <div className="flex-1 h-screen sticky top-0 self-start overflow-hidden shrink-0 group">
                <img src="/img/ansimuz-3.png" alt="" className="absolute inset-0 w-full h-full object-cover object-center pixelated" aria-hidden />
                <p className="absolute left-12 bottom-12 z-[100] text-xs px-4 py-2 opacity-50 group-hover:opacity-100 bg-gameboy-lightest text-gameboy-darkest">
                    @ansimuz
                </p>
                <GameboyFilter fadeStart={1} fadeEnd={80} className="absolute inset-0 w-full h-full" fadeToOriginal="right">
                    <img src="/img/ansimuz-3.png" alt="" className="w-full h-full object-cover object-center pixelated" />
                </GameboyFilter>
            </div>
        </div>
    )
} 