import Layout from "@/components/ui/Layout";
import { ClientViewport } from "@/components/client";

export default function ClientPage() {
    return (
        // DESIGN REFERENCE FOR THE LUA CLIENT (and for any AI working on this codebase):
        // This page is a pixel-perfect visual spec. Each ClientViewport below is one screen/state in the
        // LÖVE app. Implementations in client/src/ui/*.lua should match these viewports 1:1 (layout,
        // centering, spacing, palette). Screens: Home (Sync/Recent/Settings), Sync progress, Settings list,
        // Recent saves list, Pairing code, Unpair confirmation, and the drag/drop overlay (macOS/Windows/Linux):
        // overlay shows either "Release to add path" while dragging, or "Path added" + truncated path after drop.
        // Read inline comments in each viewport for details.
        //
        // HOW TO ACHIEVE PIXEL-PERFECT ACCURACY (for another AI with less context):
        // 1) Viewport size: ClientViewport is 640×480 (4:3). All Lua layout math uses love.graphics.getWidth()/getHeight();
        //    at runtime that is 640×480. Use these when you need fixed dimensions.
        // 2) Tailwind → Lua mapping: client/src/ui/design.lua defines tokens that match Tailwind. Use them.
        //    p-12 → design.P12 = 48   |   space-y-12 → 48 (3rem, or use a named constant)   |   space-y-6 → design.SPACE_Y_6 = 24
        //    space-y-1 → 4   |   px-4 → design.PX4 = 16   |   py-2 → design.PY2 = 8
        //    Tailwind spacing: space-y-N = N/4 rem = N*4 px (default 1rem=16px). So space-y-12 = 48px, space-y-1 = 4px.
        // 3) Centering: React uses flex items-center justify-center. In Lua, center a block by:
        //    totalH = sum of (block heights + gaps); blockTopY = (screenHeight - totalH) / 2; draw each segment at blockTopY + running offset.
        // 4) Message wrap height: use font:getWrap(msg, wrapWidth) in LÖVE; #returned_lines * lineHeight = msgH for vertical layout.
        // 5) Centered buttons (e.g. Yes/No, Sync/Recent/Settings): optionWidth = max(label widths) + 2*PX4; optionX = (screenWidth - optionWidth)/2;
        //    draw rect at (optionX, rowY, optionWidth, rowHeight); draw text with love.graphics.printf(..., 0, y, screenWidth, "center").
        // 6) Palette: client/src/ui/palette.lua and design.p (darkest, dark, light, lightest). Match dashboard globals.css / Game Boy palette.

        <div className="p-6 py-12 space-y-12">
            <ClientViewport>
                <div className="h-full flex flex-col space-y-12 items-center justify-center">

                    <p className="text-4xl">RetroSync</p>

                    <div className="text-center space-y-1">
                        <p className=" px-4 py-2">Sync</p>
                        <p className="bg-gameboy-darkest text-gameboy-lightest px-4 py-2">Recent</p>
                        <p className=" px-4 py-2">Settings</p>
                    </div>


                    <p className="opacity-50">Device: Thunder Myth 1791</p>
                </div>
            </ClientViewport>



            <ClientViewport>
                <div className="h-full flex flex-col space-y-24 items-center justify-center">

                    <div className="grid grid-cols-2 gap-24 text-center">
                        <div className="space-y-2">
                            <p className="text-8xl">14</p>
                            <p>Downloaded</p>
                        </div>
                        <div className="space-y-2">
                            <p className="text-8xl">14</p>
                            <p>Uploaded</p>
                        </div>
                    </div>

                    <div className="space-y-2 text-center">
                        <p className="text-2xl">Uploading</p>
                        <p>Let the robots do their job.</p>
                    </div>
                </div>
            </ClientViewport>

            <ClientViewport>
                <div className="h-full flex flex-col space-y-6 p-12">
                    <p className="text-xl">Settings</p>

                    <div className="space-y-2">
                        <p className="bg-gameboy-darkest text-gameboy-lightest px-4 py-2">Background process: Enabled</p>
                        <p>Unpair</p>
                        <p>Go Back</p>
                    </div>
                </div>
            </ClientViewport>

            <ClientViewport>
                <div className="h-full flex flex-col space-y-6 p-12">
                    <p className="text-xl">30 Recent Saves</p>

                    <div className="space-y-2">
                        <p>Zelda: Ocarina of Time (N64)</p>
                        <p>Super Mario 64 (N64)</p>
                        <p>Pokemon Red (GB)</p>
                        <p>Pokemon Blue (GB)</p>
                        <p className="bg-gameboy-darkest text-gameboy-lightest px-4 py-2">Pokemon Pink (GB)</p>

                        <p>Pokemon Silver (GB)</p>
                        <p>Pokemon Crystal (GB)</p>
                        <p>Pokemon Emerald (GB)</p>
                    </div>
                </div>
            </ClientViewport>

            <ClientViewport>
                <div className="h-full flex flex-col space-y-12 items-center justify-center">

                    <p className="text-4xl">RetroSync</p>

                    <div className="text-center space-y-1">
                        {/* Update with real code. */}
                        <p className="px-4 py-2 text-5xl">Ly6c8</p>
                        <p className=" px-4 py-2">Your Paring Code</p>
                    </div>

                    {/* Add motion to the 3 dots... tpying over and over agian... */}
                    <p className="opacity-50">Waiting...</p>
                </div>
            </ClientViewport>


            <ClientViewport>
                <div className="h-full flex flex-col space-y-12 items-center justify-center">

                    <p className="text-lg text-center max-w-md">Are you sure you want to unpair this device?</p>

                    <div className="text-center space-y-1">
                        <p className=" px-4 py-2">Yes</p>
                        <p className="bg-gameboy-darkest text-gameboy-lightest px-4 py-2">No</p>
                    </div>
                </div>
            </ClientViewport>


            {/* MAC OSX / WINDOWS ONLY / LINUX FEATURE */}
            <ClientViewport>
                <div className="h-full flex flex-col space-y-12 items-center justify-center">

                    <div className="inset-0 bg-gameboy-darkest/90 absolute w-full h-full z-10 text-gameboy-lightest flex flex-col items-center justify-center text-center p-12 space-y-6">
                        {/* Implement both overlay states in Lua: (1) "Path added" + truncated path (this), (2) "Release to add path" while dragging. */}
                        <p className="text-5xl">Path added to Sync. Now tracking.</p>
                        {/* <p className="text-5xl">Release to add path</p> */}
                        {/* Path line: max one line, truncate with ellipsis. */}
                        <p className="">/Path/To/MyFile/Example/Here...</p>
                    </div>

                    <p className="text-4xl">RetroSync</p>

                    <div className="text-center space-y-1">
                        <p className=" px-4 py-2">Sync</p>
                        <p className="bg-gameboy-darkest text-gameboy-lightest px-4 py-2">Recent</p>
                        <p className=" px-4 py-2">Settings</p>
                    </div>


                    <p className="opacity-50">Device: Thunder Myth 1791</p>
                </div>
            </ClientViewport>


            <ClientViewport>
                <div className="h-full flex flex-col space-y-12 items-center justify-center">

                    <div className="inset-0 bg-gameboy-darkest/90 absolute w-full h-full z-10 text-gameboy-lightest flex flex-col items-center justify-center text-center p-12 space-y-6">
                        {/* Add motion to the dots... tpying over and over agian... */}
                        <p className="text-5xl">Loading...</p>
                    </div>

                    <p className="text-4xl">RetroSync</p>

                    <div className="text-center space-y-1">
                        <p className=" px-4 py-2">Sync</p>
                        <p className="bg-gameboy-darkest text-gameboy-lightest px-4 py-2">Recent</p>
                        <p className=" px-4 py-2">Settings</p>
                    </div>


                    <p className="opacity-50">Device: Thunder Myth 1791</p>
                </div>
            </ClientViewport>


            {/* No paths (macOS/desktop: no preconfigured folders). Shown once after pairing; dismiss with A or click. */}
            <ClientViewport>
                <div className="h-full flex flex-col space-y-12 items-center justify-center">
                    <p className="p-12 text-2xl">RetroSync has not detected any paths with save files. To add a path, drag and drop a folder onto the RetroSync app's window at anytime or enter your device settings on your dashboard.</p>
                </div>
            </ClientViewport>

        </div>
    );
}