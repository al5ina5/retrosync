import Link from 'next/link'

export default function Home() {
  return (
    <main className="min-h-screen bg-vercel-black text-vercel-white">
      {/* Navigation */}
      <nav className="border-b border-vercel-gray-800">
        <div className="container mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex h-16 items-center justify-between">
            <div className="flex items-center">
              <Link href="/" className="text-xl font-semibold">
                RetroSync
              </Link>
            </div>
            <div className="flex items-center gap-4">
              <Link
                href="/auth/login"
                className="text-vercel-gray-400 hover:text-vercel-white transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-vercel-blue-500 focus-visible:ring-offset-2 focus-visible:ring-offset-vercel-black rounded px-3 py-2"
              >
                Login
              </Link>
              <Link
                href="/auth/register"
                className="bg-vercel-white text-vercel-black hover:bg-vercel-gray-200 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-vercel-blue-500 focus-visible:ring-offset-2 focus-visible:ring-offset-vercel-black rounded px-4 py-2 font-medium"
              >
                Get Started
              </Link>
            </div>
          </div>
        </div>
      </nav>

      {/* Hero Section */}
      <section className="container mx-auto px-4 sm:px-6 lg:px-8 py-24 sm:py-32">
        <div className="max-w-4xl mx-auto text-center">
          <h1 className="text-5xl sm:text-6xl lg:text-7xl font-bold mb-6 text-pretty">
            Cloud Sync for Retro Gaming
          </h1>
          <p className="text-xl sm:text-2xl text-vercel-gray-400 mb-12 max-w-2xl mx-auto text-pretty">
            Automatically sync your save files across Anbernic, Miyoo handhelds, and PC. Never lose your progress again.
          </p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <Link
              href="/auth/register"
              className="bg-vercel-white text-vercel-black hover:bg-vercel-gray-200 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-vercel-blue-500 focus-visible:ring-offset-2 focus-visible:ring-offset-vercel-black rounded-lg px-8 py-4 font-semibold text-lg"
            >
              Get Started
            </Link>
            <Link
              href="/auth/login"
              className="border border-vercel-gray-800 text-vercel-white hover:border-vercel-gray-700 hover:bg-vercel-gray-900 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-vercel-blue-500 focus-visible:ring-offset-2 focus-visible:ring-offset-vercel-black rounded-lg px-8 py-4 font-semibold text-lg"
            >
              Login
            </Link>
          </div>
        </div>
      </section>

      {/* Features Grid */}
      <section className="container mx-auto px-4 sm:px-6 lg:px-8 py-16 sm:py-24">
        <div className="grid md:grid-cols-3 gap-8 max-w-6xl mx-auto">
          <div className="border border-vercel-gray-800 rounded-lg p-8 hover:border-vercel-gray-700 transition-colors">
            <div className="text-4xl mb-4" aria-hidden="true">🎮</div>
            <h3 className="text-xl font-semibold mb-2">Multi-Device Support</h3>
            <p className="text-vercel-gray-400">
              Works with Anbernic RG35XX+ (muOS), Miyoo Flip (Spruce OS), Windows, Mac, and Linux
            </p>
          </div>

          <div className="border border-vercel-gray-800 rounded-lg p-8 hover:border-vercel-gray-700 transition-colors">
            <div className="text-4xl mb-4" aria-hidden="true">⚡</div>
            <h3 className="text-xl font-semibold mb-2">Automatic Sync</h3>
            <p className="text-vercel-gray-400">
              File changes are detected and synced automatically in real-time
            </p>
          </div>

          <div className="border border-vercel-gray-800 rounded-lg p-8 hover:border-vercel-gray-700 transition-colors">
            <div className="text-4xl mb-4" aria-hidden="true">🔒</div>
            <h3 className="text-xl font-semibold mb-2">Your Data, Your Control</h3>
            <p className="text-vercel-gray-400">
              Self-hosted solution with local-first architecture and full data control
            </p>
          </div>
        </div>
      </section>

      {/* How It Works */}
      <section className="container mx-auto px-4 sm:px-6 lg:px-8 py-16 sm:py-24">
        <div className="max-w-4xl mx-auto">
          <div className="border border-vercel-gray-800 rounded-lg p-8 sm:p-12">
            <h2 className="text-3xl sm:text-4xl font-bold mb-12 text-center text-pretty">How It Works</h2>
            <div className="space-y-8">
              <div className="flex items-start gap-6">
                <div className="bg-vercel-white text-vercel-black rounded-full w-10 h-10 flex items-center justify-center flex-shrink-0 font-bold text-lg" aria-hidden="true">
                  1
                </div>
                <div>
                  <h4 className="font-semibold mb-2 text-lg">Create an Account</h4>
                  <p className="text-vercel-gray-400">Sign up for free and access your dashboard</p>
                </div>
              </div>

              <div className="flex items-start gap-6">
                <div className="bg-vercel-white text-vercel-black rounded-full w-10 h-10 flex items-center justify-center flex-shrink-0 font-bold text-lg" aria-hidden="true">
                  2
                </div>
                <div>
                  <h4 className="font-semibold mb-2 text-lg">Pair Your Devices</h4>
                  <p className="text-vercel-gray-400">
                    Generate a pairing code and enter it on your device
                  </p>
                </div>
              </div>

              <div className="flex items-start gap-6">
                <div className="bg-vercel-white text-vercel-black rounded-full w-10 h-10 flex items-center justify-center flex-shrink-0 font-bold text-lg" aria-hidden="true">
                  3
                </div>
                <div>
                  <h4 className="font-semibold mb-2 text-lg">Start Gaming</h4>
                  <p className="text-vercel-gray-400">
                    Your save files sync automatically across all paired devices
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-vercel-gray-800 mt-24">
        <div className="container mx-auto px-4 sm:px-6 lg:px-8 py-12">
          <div className="text-center text-vercel-gray-400">
            <p>&copy; {new Date().getFullYear()} RetroSync. All rights reserved.</p>
          </div>
        </div>
      </footer>
    </main>
  )
}
