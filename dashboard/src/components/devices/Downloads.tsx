import { Button } from "../ui";

export default function Downloads() {
    return (
        <div className="border-2 border-gameboy-darkest p-6 md:p-12 space-y-12">
            <div className="space-y-6">
                <p className="text-2xl">Downloads</p>
                <p>Download the RetroSync client for your device to begin syncing your saves.</p>
            </div>

            <div className="space-y-6">
                <div className="space-y-2">
                    <Button variant="primary">PortMaster </Button>
                    <p className="text-sm">Support Ambernic devices, Miyoo devices, and more on a variety of operating systems. Choose your platform below.</p>
                </div>

                <div className="space-y-2">
                    <div><Button variant="primary">MacOSX</Button></div>
                    <p className="text-sm">Supports a variety of emulators.</p>
                </div>

                <div className="space-y-2">
                    <div><Button variant="primary">Windows</Button></div>
                    <p className="text-sm">Supports a variety of emulators.</p>
                </div>

                <div className="space-y-2">
                    <div><Button variant="primary">Linux</Button></div>
                    <p className="text-sm">Supports a variety of emulators.</p>
                </div>

            </div>
        </div>
    );
}