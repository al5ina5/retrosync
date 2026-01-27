import Link from 'next/link'

export default function Home() {
  return (
    <main className="min-h-screen bg-gradient-to-b from-gray-900 to-gray-800 text-white">
      <div className="container mx-auto px-4 py-16">
        <div className="text-center mb-16">
          <h1 className="text-6xl font-bold mb-4">RetroSync</h1>
          <p className="text-2xl text-gray-300 mb-8">
            Cloud sync for retro gaming save files
          </p>
          <p className="text-lg text-gray-400 max-w-2xl mx-auto mb-12">
            Automatically sync your save files across Anbernic, Miyoo handhelds, and PC.
            Never lose your progress again.
          </p>
          <div className="flex gap-4 justify-center">
            <Link
              href="/auth/register"
              className="px-8 py-4 bg-blue-600 hover:bg-blue-700 rounded-lg font-semibold text-lg transition-colors"
            >
              Get Started
            </Link>
            <Link
              href="/auth/login"
              className="px-8 py-4 bg-gray-700 hover:bg-gray-600 rounded-lg font-semibold text-lg transition-colors"
            >
              Login
            </Link>
          </div>
        </div>

        <div className="grid md:grid-cols-3 gap-8 max-w-5xl mx-auto mb-16">
          <div className="bg-gray-800 p-8 rounded-lg">
            <div className="text-4xl mb-4">🎮</div>
            <h3 className="text-xl font-bold mb-2">Multi-Device Support</h3>
            <p className="text-gray-400">
              Works with Anbernic RG35XX+ (muOS), Miyoo Flip (Spruce OS), Windows, Mac, and Linux
            </p>
          </div>

          <div className="bg-gray-800 p-8 rounded-lg">
            <div className="text-4xl mb-4">⚡</div>
            <h3 className="text-xl font-bold mb-2">Automatic Sync</h3>
            <p className="text-gray-400">
              File changes are detected and synced automatically in real-time
            </p>
          </div>

          <div className="bg-gray-800 p-8 rounded-lg">
            <div className="text-4xl mb-4">🔒</div>
            <h3 className="text-xl font-bold mb-2">Your Data, Your Control</h3>
            <p className="text-gray-400">
              Self-hosted solution with local-first architecture and full data control
            </p>
          </div>
        </div>

        <div className="bg-gray-800 p-8 rounded-lg max-w-4xl mx-auto">
          <h2 className="text-3xl font-bold mb-6 text-center">How It Works</h2>
          <div className="space-y-6">
            <div className="flex items-start gap-4">
              <div className="bg-blue-600 rounded-full w-8 h-8 flex items-center justify-center flex-shrink-0 font-bold">
                1
              </div>
              <div>
                <h4 className="font-bold mb-1">Create an account</h4>
                <p className="text-gray-400">Sign up for free and access your dashboard</p>
              </div>
            </div>

            <div className="flex items-start gap-4">
              <div className="bg-blue-600 rounded-full w-8 h-8 flex items-center justify-center flex-shrink-0 font-bold">
                2
              </div>
              <div>
                <h4 className="font-bold mb-1">Pair your devices</h4>
                <p className="text-gray-400">
                  Generate a pairing code and enter it on your device
                </p>
              </div>
            </div>

            <div className="flex items-start gap-4">
              <div className="bg-blue-600 rounded-full w-8 h-8 flex items-center justify-center flex-shrink-0 font-bold">
                3
              </div>
              <div>
                <h4 className="font-bold mb-1">Start gaming</h4>
                <p className="text-gray-400">
                  Your save files sync automatically across all paired devices
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </main>
  )
}
