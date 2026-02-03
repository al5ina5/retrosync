import { Button } from "../ui";

export default function Downloads() {
    const base = "https://github.com/al5ina5/retrosyncd/releases/latest/download";
    const downloads = {
        portmaster: `${base}/retrosync-portmaster.zip`,
        macos: `${base}/retrosync-macos.zip`,
        windows: `${base}/retrosync-windows.zip`,
        linux: `${base}/retrosync-linux.zip`,
        love: `${base}/retrosync.love`,
    };

    return (
        <div className="border-2 border-gameboy-darkest p-6 md:p-12 space-y-12">
            <div className="space-y-6">
                <p className="text-2xl">Downloads</p>
                <p>Download the RetroSync client for your device to begin syncing your saves.</p>
            </div>

            <div className="space-y-6">
                <div className="space-y-2">
                    <a href={downloads.portmaster}>
                        <Button variant="primary">PortMaster</Button>
                    </a>
                    <p className="text-sm">Support Ambernic devices, Miyoo devices, and more on a variety of operating systems. Choose your platform below.</p>
                </div>

                <div className="space-y-2">
                    <div>
                        <a href={downloads.macos}>
                            <Button variant="primary">macOS</Button>
                        </a>
                    </div>
                    <p className="text-sm">Supports a variety of emulators.</p>
                </div>

                <div className="space-y-2">
                    <div>
                        <a href={downloads.windows}>
                            <Button variant="primary">Windows</Button>
                        </a>
                    </div>
                    <p className="text-sm">Bundled executable with the LÖVE runtime (64-bit).</p>
                </div>

                <div className="space-y-2">
                    <div>
                        <a href={downloads.linux}>
                            <Button variant="primary">Linux</Button>
                        </a>
                    </div>
                    <p className="text-sm">Includes LÖVE runtime and launch script.</p>
                </div>

                <div className="space-y-2">
                    <div>
                        <a href={downloads.love}>
                            <Button variant="primary">LÖVE</Button>
                        </a>
                    </div>
                    <p className="text-sm">Just the .love file—run with your own LÖVE 11.x.</p>
                </div>

            </div>
        </div>
    );
}
