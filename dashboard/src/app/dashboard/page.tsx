'use client'

import { useEffect } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import useSWR from 'swr'
import { fetcher } from '@/lib/utils'
import AnimatedLogo from '@/components/AnimatedLogo'

interface Device {
  id: string
  name: string
  deviceType: string
  lastSyncAt: string | null
  isActive: boolean
  createdAt: string
}

interface DevicesResponse {
  devices: Device[]
}

export default function DashboardPage() {
  const router = useRouter()

  // Check authentication
  useEffect(() => {
    const token = localStorage.getItem('token')
    if (!token) {
      router.push('/auth/login')
    }
  }, [router])

  // Fetch devices with SWR
  const { data, error, isLoading } = useSWR<DevicesResponse>(
    typeof window !== 'undefined' && localStorage.getItem('token') ? '/api/devices' : null,
    fetcher
  )

  const devices = data?.devices || []

  const logout = () => {
    localStorage.removeItem('token')
    localStorage.removeItem('user')
    router.push('/')
  }

  if (isLoading) {
    return (
      <div className="min-h-screen bg-vercel-black flex flex-col items-center justify-center">
        <AnimatedLogo className="mb-8" />
        <div className="text-vercel-white text-xl">Loading…</div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-vercel-black text-vercel-white">
      {/* Navigation */}
      <nav className="border-b border-vercel-gray-800">
        <div className="container mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex h-16 items-center justify-between">
            <div className="flex items-center">
              <Link href="/" className="text-xl font-semibold hover:text-vercel-gray-300 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-vercel-blue-500 focus-visible:ring-offset-2 focus-visible:ring-offset-vercel-black rounded">
                RetroSync
              </Link>
            </div>
            <button
              onClick={logout}
              className="text-vercel-gray-400 hover:text-vercel-white transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-vercel-blue-500 focus-visible:ring-offset-2 focus-visible:ring-offset-vercel-black rounded px-3 py-2"
            >
              Logout
            </button>
          </div>
        </div>
      </nav>

      {/* Main Content */}
      <main className="container mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="mb-12 text-center">
          <AnimatedLogo className="mb-6 text-5xl sm:text-6xl lg:text-7xl font-bold" />
          <h1 className="text-4xl font-bold mb-2">Dashboard</h1>
          <p className="text-vercel-gray-400">Manage your devices and save files</p>
        </div>

        {error && (
          <div
            className="bg-red-500/10 border border-red-500/50 text-red-400 px-4 py-3 rounded-lg mb-6"
            role="alert"
            aria-live="polite"
          >
            {error instanceof Error ? error.message : 'Failed to fetch devices'}
          </div>
        )}

        <div className="grid lg:grid-cols-2 gap-6">
          {/* Devices Card */}
          <Link
            href="/dashboard/devices"
            className="block border border-vercel-gray-800 rounded-lg p-6 hover:border-vercel-gray-700 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-vercel-blue-500 focus-visible:ring-offset-2 focus-visible:ring-offset-vercel-black"
          >
            <h2 className="text-2xl font-semibold mb-2">My Devices</h2>
            <p className="text-vercel-gray-400 mb-4">
              Add new devices or manage existing ones
            </p>
            {devices.length > 0 && (
              <div className="mt-4">
                <p className="text-sm text-vercel-gray-500 mb-2">
                  {devices.length} {devices.length === 1 ? 'device' : 'devices'} paired
                </p>
                <div className="space-y-2">
                  {devices.slice(0, 2).map((device) => (
                    <div key={device.id} className="border border-vercel-gray-800 rounded-lg p-3">
                      <div className="flex justify-between items-start">
                        <div>
                          <h4 className="font-semibold text-sm">{device.name}</h4>
                          <p className="text-xs text-vercel-gray-400">{device.deviceType}</p>
                        </div>
                        <span className={`text-xs ${device.isActive ? 'text-green-400' : 'text-vercel-gray-500'
                          }`}>
                          {device.isActive ? 'Active' : 'Inactive'}
                        </span>
                      </div>
                    </div>
                  ))}
                  {devices.length > 2 && (
                    <p className="text-xs text-vercel-gray-500 text-center">
                      +{devices.length - 2} more
                    </p>
                  )}
                </div>
              </div>
            )}
            <span className="inline-block mt-4 text-vercel-blue-400 hover:text-vercel-blue-300 font-medium">
              Manage Devices →
            </span>
          </Link>

          {/* Saves Card */}
          <Link
            href="/dashboard/saves"
            className="block border border-vercel-gray-800 rounded-lg p-6 hover:border-vercel-gray-700 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-vercel-blue-500 focus-visible:ring-offset-2 focus-visible:ring-offset-vercel-black"
          >
            <h2 className="text-2xl font-semibold mb-2">My Saves</h2>
            <p className="text-vercel-gray-400 mb-4">
              View and manage your uploaded save files
            </p>
            <span className="inline-block mt-4 text-vercel-blue-400 hover:text-vercel-blue-300 font-medium">
              Recent →
            </span>
          </Link>
        </div>
      </main>
    </div>
  )
}
