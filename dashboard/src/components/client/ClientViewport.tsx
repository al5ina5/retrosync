"use client";

import { useRef, useCallback } from "react";
import html2canvas from "html2canvas";

/**
 * 640×480 (4:3) viewport matching the LÖVE client window.
 * Design mockups here; screenshots at this size match the client 1:1.
 */
export default function ClientViewport({
    children,
    className = "",
}: {
    children?: React.ReactNode;
    className?: string;
}) {
    const viewportRef = useRef<HTMLDivElement>(null);

    const handleDownloadScreenshot = useCallback(async () => {
        const el = viewportRef.current;
        if (!el) return;
        try {
            // Wait for fonts (e.g. Game Boy) so text renders correctly
            await document.fonts?.ready;

            const width = el.offsetWidth;
            const height = el.offsetHeight;
            // Scale so output is exactly 640×480 (LÖVE client size)
            const scale = Math.min(640 / width, 480 / height);

            const canvas = await html2canvas(el, {
                scale,
                useCORS: true,
                allowTaint: true,
                backgroundColor: null,
                logging: false,
                scrollX: 0,
                scrollY: 0,
            });

            // Normalize to exactly 640×480 (avoids rounding/DPI quirks)
            const out = document.createElement("canvas");
            out.width = 640;
            out.height = 480;
            const ctx = out.getContext("2d");
            if (ctx) {
                ctx.imageSmoothingEnabled = false;
                ctx.drawImage(canvas, 0, 0, canvas.width, canvas.height, 0, 0, 640, 480);
            }
            const exportCanvas = ctx ? out : canvas;

            const blob = await new Promise<Blob | null>((resolve) =>
                exportCanvas.toBlob(resolve, "image/png", 1)
            );
            if (!blob) return;
            const url = URL.createObjectURL(blob);
            const a = document.createElement("a");
            a.href = url;
            a.download = `client-viewport-${Date.now()}.png`;
            a.click();
            URL.revokeObjectURL(url);
        } catch (err) {
            console.error("Screenshot failed:", err);
        }
    }, []);

    return (
        <div className="w-full flex justify-center">
            <div className="group relative w-full max-w-[640px] aspect-[4/3]" style={{ minHeight: 0 }}>
                <div
                    ref={viewportRef}
                    className={`w-full h-full border-2 border-gameboy-darkest overflow-hidden ${className}`}
                >
                    <div className="w-full h-full p-6 box-border">{children}</div>
                </div>
                <button
                    type="button"
                    onClick={handleDownloadScreenshot}
                    className="absolute bottom-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity rounded px-2 py-1 text-xs font-medium bg-gameboy-darkest text-gameboy-light border border-gameboy-dark hover:bg-gameboy-dark focus:outline-none focus:ring-2 focus:ring-gameboy-light/50"
                    title="Download as screenshot"
                >
                    Download
                </button>
            </div>
        </div>
    );
}
