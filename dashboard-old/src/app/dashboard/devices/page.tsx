'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import useSWR, { mutate } from 'swr'
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

export default function DevicesPage() {
  const router = useRouter()
  const [deviceCodeInput, setDeviceCodeInput] = useState('')
  const [isPairing, setIsPairing] = useState(false)
  const [pairingSuccess, setPairingSuccess] = useState(false)
  const [error, setError] = useState('')

  // Check authentication
  useEffect(() => {
    const token = localStorage.getItem('token')
    if (!token) {
      router.push('/auth/login')
    }
  }, [router])

  // Fetch devices with SWR
  const { data, error: swrError, isLoading } = useSWR<DevicesResponse>(
    typeof window !== 'undefined' && localStorage.getItem('token') ? '/api/devices' : null,
    fetcher,
    {
      refreshInterval: pairingSuccess ? 2000 : 0, // Poll every 2s when pairing
      onError: (err) => {
        if (err instanceof Error && err.message !== 'Unauthorized') {
          setError(err.message)
        }
      },
    }
  )

  const devices = data?.devices || []

  const handleDeviceCodeSubmit = async () => {
    if (deviceCodeInput.length !== 6) {
      setError('Code must be 6 characters')
      return
    }

    setIsPairing(true)
    setError('')
    setPairingSuccess(false)

    try {
      const token = localStorage.getItem('token')
      const response = await fetch('/api/devices/pair', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ code: deviceCodeInput }),
      })

      const data = await response.json()

      if (data.success) {
        setPairingSuccess(true)
        setDeviceCodeInput('')
        // Start polling for device to appear
        setTimeout(() => {
          setPairingSuccess(false)
        }, 30000) // Stop polling after 30 seconds
      } else {
        setError(data.error || 'Failed to link code')
      }
    } catch (err) {
      setError('Failed to link code')
    } finally {
      setIsPairing(false)
    }
  }

  const deleteDevice = async (deviceId: string) => {
    if (!confirm('Are you sure you want to remove this device?')) {
      return
    }

    try {
      const token = localStorage.getItem('token')
      const response = await fetch(`/api/devices?id=${deviceId}`, {
        method: 'DELETE',
        headers: {
          'Authorization': `Bearer ${token}`,
        },
      })

      const data = await response.json()

      if (data.success) {
        // Revalidate devices list
        mutate('/api/devices')
        setError('')
      } else {
        setError(data.error || 'Failed to delete device')
      }
    } catch (err) {
      setError('Failed to delete device')
    }
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
            <div className="flex items-center gap-6">
              <Link href="/" className="text-xl font-semibold hover:text-vercel-gray-300 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-vercel-blue-500 focus-visible:ring-offset-2 focus-visible:ring-offset-vercel-black rounded">
                RetroSync
              </Link>
              <Link
                href="/dashboard"
                className="text-vercel-gray-400 hover:text-vercel-white transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-vercel-blue-500 focus-visible:ring-offset-2 focus-visible:ring-offset-vercel-black rounded px-3 py-2"
              >
                ← Back to Dashboard
              </Link>
            </div>
          </div>
        </div>
      </nav>

      {/* Main Content */}
      <main className="container mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="mb-12 text-center">
          <AnimatedLogo className="mb-6 text-5xl sm:text-6xl lg:text-7xl font-bold" />
          <h1 className="text-4xl font-bold mb-2">My Devices</h1>
          <p className="text-vercel-gray-400">Add and manage your paired devices</p>
        </div>

        {(error || swrError) && (
          <div
            className="bg-red-500/10 border border-red-500/50 text-red-400 px-4 py-3 rounded-lg mb-6"
            role="alert"
            aria-live="polite"
          >
            {error || (swrError instanceof Error ? swrError.message : 'Failed to fetch devices')}
          </div>
        )}

        <div className="grid lg:grid-cols-2 gap-8">
          {/* Code Entry Section */}
          <div className="border border-vercel-gray-800 rounded-lg p-6 sm:p-8">
            <h2 className="text-2xl font-semibold mb-6">Add Device</h2>
            <div className="space-y-6">
              <div>
                <label
                  htmlFor="device-code"
                  className="block text-sm font-medium text-vercel-gray-300 mb-3"
                >
                  Enter the 6-character code from your Miyoo device
                </label>
                <div className="flex gap-3">
                  <input
                    type="text"
                    id="device-code"
                    name="device-code"
                    inputMode="text"
                    pattern="[A-Z0-9]*"
                    maxLength={6}
                    value={deviceCodeInput}
                    onChange={(e) => {
                      const value = e.target.value.toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 6)
                      setDeviceCodeInput(value)
                      setError('')
                    }}
                    onKeyDown={(e) => {
                      if (e.key === 'Enter' && deviceCodeInput.length === 6 && !isPairing) {
                        handleDeviceCodeSubmit()
                      }
                    }}
                    placeholder="ABC123"
                    className="flex-1 bg-vercel-black border border-vercel-gray-800 text-vercel-white text-3xl font-bold tracking-wider text-center py-4 px-6 rounded-lg focus:outline-none focus:ring-2 focus:ring-vercel-blue-500 focus:border-transparent transition-colors"
                    aria-label="6-character device pairing code"
                    autoComplete="off"
                    spellCheck={false}
                  />
                </div>
                <p className="text-sm text-vercel-gray-500 mt-2">
                  Enter the code displayed on your device screen
                </p>
              </div>

              {pairingSuccess && (
                <div
                  className="bg-green-500/10 border border-green-500/50 text-green-400 px-4 py-3 rounded-lg"
                  role="alert"
                  aria-live="polite"
                >
                  Code linked! The device should detect it automatically and show the UPLOAD button. The device will appear in your devices list once it pairs.
                </div>
              )}

              <button
                onClick={handleDeviceCodeSubmit}
                disabled={deviceCodeInput.length !== 6 || isPairing}
                className="w-full px-4 py-3 bg-vercel-white text-vercel-black hover:bg-vercel-gray-200 disabled:bg-vercel-gray-800 disabled:text-vercel-gray-500 disabled:cursor-not-allowed rounded-lg transition-colors font-semibold focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-vercel-blue-500 focus-visible:ring-offset-2 focus-visible:ring-offset-vercel-black"
              >
                {isPairing ? 'Pairing…' : 'Pair Device'}
              </button>

              <p className="text-sm text-vercel-gray-400 text-center">
                After entering the code, your device will automatically detect the link and show the UPLOAD button.
              </p>
            </div>
          </div>

          {/* Devices List */}
          <div className="border border-vercel-gray-800 rounded-lg p-6 sm:p-8">
            <div className="flex justify-between items-center mb-6">
              <h2 className="text-2xl font-semibold">Your Devices</h2>
              <span className="text-sm text-vercel-gray-400">
                {devices.length} {devices.length === 1 ? 'device' : 'devices'}
              </span>
            </div>

            {devices.length === 0 ? (
              <div className="text-center py-12">
                <p className="text-vercel-gray-400 mb-2">No devices paired yet</p>
                <p className="text-sm text-vercel-gray-500">
                  Add your first device using the code entry form
                </p>
              </div>
            ) : (
              <div className="space-y-4">
                {devices.map((device) => (
                  <div key={device.id} className="border border-vercel-gray-800 rounded-lg p-4 hover:border-vercel-gray-700 transition-colors">
                    <div className="flex justify-between items-start mb-3">
                      <div className="flex-1 min-w-0">
                        <h3 className="font-semibold text-lg mb-1 truncate">{device.name}</h3>
                        <p className="text-sm text-vercel-gray-400">{device.deviceType}</p>
                      </div>
                      <button
                        onClick={() => deleteDevice(device.id)}
                        className="text-red-400 hover:text-red-300 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-red-500 focus-visible:ring-offset-2 focus-visible:ring-offset-vercel-black rounded px-2 py-1 text-sm font-medium"
                        aria-label={`Remove device ${device.name}`}
                      >
                        Remove
                      </button>
                    </div>
                    <div className="space-y-1 text-sm">
                      <p className="text-vercel-gray-400">
                        Last sync: <span className="text-vercel-gray-300">
                          {device.lastSyncAt
                            ? new Intl.DateTimeFormat('en-US', {
                              dateStyle: 'medium',
                              timeStyle: 'short',
                            }).format(new Date(device.lastSyncAt))
                            : 'Never'}
                        </span>
                      </p>
                      <p className="text-vercel-gray-400">
                        Status: <span className={device.isActive ? 'text-green-400' : 'text-vercel-gray-500'}>
                          {device.isActive ? 'Active' : 'Inactive'}
                        </span>
                      </p>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      </main>
    </div>
  )
}
