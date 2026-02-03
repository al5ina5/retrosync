import { Button } from "../ui";

export default function Downloads() {
    const base = "https://github.com/al5ina5/retrosyncd/releases/latest/download";
    const downloads = {
        portmaster: `${base}/retrosync-portmaster-latest.zip`,
        macos: `${base}/retrosync-macos-latest.zip`,
        desktopLove: `${base}/retrosync-desktop-latest.love`,
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
                        <a href={downloads.desktopLove}>
                            <Button variant="primary">Windows (LÖVE)</Button>
                        </a>
                    </div>
                    <p className="text-sm">Download the .love file and run with LÖVE 11.x.</p>
                </div>

                <div className="space-y-2">
                    <div>
                        <a href={downloads.desktopLove}>
                            <Button variant="primary">Linux (LÖVE)</Button>
                        </a>
                    </div>
                    <p className="text-sm">Download the .love file and run with LÖVE 11.x.</p>
                </div>

            </div>
        </div>
    );
}
