'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'

interface Device {
  id: string
  name: string
  deviceType: string
  lastSyncAt: string | null
  isActive: boolean
  createdAt: string
}

interface PairingCode {
  code: string
  expiresAt: string
  qrCode: string
}

export default function DashboardPage() {
  const router = useRouter()
  const [devices, setDevices] = useState<Device[]>([])
  const [pairingCode, setPairingCode] = useState<PairingCode | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    const token = localStorage.getItem('token')
    if (!token) {
      router.push('/auth/login')
      return
    }

    fetchDevices()
  }, [router])

  const fetchDevices = async () => {
    try {
      const token = localStorage.getItem('token')
      const response = await fetch('/api/devices', {
        headers: {
          'Authorization': `Bearer ${token}`,
        },
      })

      const data = await response.json()

      if (data.success) {
        setDevices(data.data.devices)
      } else {
        setError(data.error || 'Failed to fetch devices')
      }
    } catch (err) {
      setError('Failed to fetch devices')
    } finally {
      setLoading(false)
    }
  }

  const generatePairingCode = async () => {
    try {
      const token = localStorage.getItem('token')
      const response = await fetch('/api/devices/create-pairing-code', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
        },
      })

      const data = await response.json()

      if (data.success) {
        setPairingCode(data.data)
      } else {
        setError(data.error || 'Failed to generate pairing code')
      }
    } catch (err) {
      setError('Failed to generate pairing code')
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
        fetchDevices()
      } else {
        setError(data.error || 'Failed to delete device')
      }
    } catch (err) {
      setError('Failed to delete device')
    }
  }

  const logout = () => {
    localStorage.removeItem('token')
    localStorage.removeItem('user')
    router.push('/')
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-b from-gray-900 to-gray-800 flex items-center justify-center">
        <div className="text-white text-xl">Loading...</div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gradient-to-b from-gray-900 to-gray-800 text-white">
      <div className="container mx-auto px-4 py-8">
        <div className="flex justify-between items-center mb-8">
          <h1 className="text-4xl font-bold">RetroSync Dashboard</h1>
          <button
            onClick={logout}
            className="px-4 py-2 bg-gray-700 hover:bg-gray-600 rounded-lg transition-colors"
          >
            Logout
          </button>
        </div>

        {error && (
          <div className="bg-red-500/10 border border-red-500 text-red-500 px-4 py-3 rounded mb-6">
            {error}
          </div>
        )}

        <div className="grid lg:grid-cols-2 gap-8">
          {/* Devices Section */}
          <div className="bg-gray-800 rounded-lg p-6">
            <div className="flex justify-between items-center mb-6">
              <h2 className="text-2xl font-bold">Your Devices</h2>
              <button
                onClick={generatePairingCode}
                className="px-4 py-2 bg-blue-600 hover:bg-blue-700 rounded-lg transition-colors"
              >
                + Add Device
              </button>
            </div>

            {devices.length === 0 ? (
              <p className="text-gray-400">No devices paired yet. Add your first device to get started.</p>
            ) : (
              <div className="space-y-4">
                {devices.map((device) => (
                  <div key={device.id} className="bg-gray-700 rounded-lg p-4">
                    <div className="flex justify-between items-start mb-2">
                      <div>
                        <h3 className="font-bold text-lg">{device.name}</h3>
                        <p className="text-sm text-gray-400">{device.deviceType}</p>
                      </div>
                      <button
                        onClick={() => deleteDevice(device.id)}
                        className="text-red-500 hover:text-red-400"
                      >
                        Remove
                      </button>
                    </div>
                    <div className="text-sm text-gray-400">
                      <p>
                        Last sync: {device.lastSyncAt
                          ? new Date(device.lastSyncAt).toLocaleString()
                          : 'Never'}
                      </p>
                      <p>
                        Status: <span className={device.isActive ? 'text-green-500' : 'text-gray-500'}>
                          {device.isActive ? 'Active' : 'Inactive'}
                        </span>
                      </p>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Pairing Code Section */}
          {pairingCode && (
            <div className="bg-gray-800 rounded-lg p-6">
              <h2 className="text-2xl font-bold mb-6">Pairing Code</h2>
              <div className="text-center">
                <p className="text-gray-400 mb-4">Enter this code on your device:</p>
                <div className="bg-gray-700 rounded-lg p-8 mb-4">
                  <div className="text-5xl font-bold tracking-wider">{pairingCode.code}</div>
                </div>
                {pairingCode.qrCode && (
                  <div className="mb-4">
                    <p className="text-gray-400 mb-2">Or scan this QR code:</p>
                    <img
                      src={pairingCode.qrCode}
                      alt="Pairing QR Code"
                      className="mx-auto"
                    />
                  </div>
                )}
                <p className="text-sm text-gray-400">
                  Code expires at: {new Date(pairingCode.expiresAt).toLocaleString()}
                </p>
                <button
                  onClick={() => setPairingCode(null)}
                  className="mt-4 px-4 py-2 bg-gray-700 hover:bg-gray-600 rounded-lg transition-colors"
                >
                  Close
                </button>
              </div>
            </div>
          )}

          {/* Quick Links */}
          {!pairingCode && (
            <div className="bg-gray-800 rounded-lg p-6">
              <h2 className="text-2xl font-bold mb-6">Quick Links</h2>
              <div className="space-y-4">
                <Link
                  href="/dashboard/devices"
                  className="block bg-gray-700 hover:bg-gray-600 rounded-lg p-4 transition-colors"
                >
                  <h3 className="font-bold mb-1">Device Management</h3>
                  <p className="text-sm text-gray-400">View and manage all your paired devices</p>
                </Link>
                <a
                  href="https://github.com/anthropics/retrosync"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="block bg-gray-700 hover:bg-gray-600 rounded-lg p-4 transition-colors"
                >
                  <h3 className="font-bold mb-1">Documentation</h3>
                  <p className="text-sm text-gray-400">Learn how to set up and use RetroSync</p>
                </a>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
