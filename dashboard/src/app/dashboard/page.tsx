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

interface Save {
  filePath: string
  fileName: string
  fileSize: number
  uploadedAt: string
  device: {
    id: string
    name: string
    deviceType: string
  }
}

function SavesTab() {
  const [saves, setSaves] = useState<Save[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    fetchSaves()
  }, [])

  const fetchSaves = async () => {
    try {
      const token = localStorage.getItem('token')
      const response = await fetch('/api/saves', {
        headers: {
          'Authorization': `Bearer ${token}`,
        },
      })

      const data = await response.json()

      if (data.success) {
        setSaves(data.data.saves)
      } else {
        setError(data.error || 'Failed to fetch saves')
      }
    } catch (err) {
      setError('Failed to fetch saves')
    } finally {
      setLoading(false)
    }
  }

  const formatFileSize = (bytes: number): string => {
    if (bytes === 0) return '0 B'
    const k = 1024
    const sizes = ['B', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i]
  }

  if (loading) {
    return (
      <div className="border border-vercel-gray-800 rounded-lg p-8 text-center">
        <div className="text-vercel-white text-xl">Loading saves…</div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {error && (
        <div 
          className="bg-red-500/10 border border-red-500/50 text-red-400 px-4 py-3 rounded-lg"
          role="alert"
          aria-live="polite"
        >
          {error}
        </div>
      )}

      {saves.length === 0 ? (
        <div className="border border-vercel-gray-800 rounded-lg p-12 text-center">
          <h2 className="text-2xl font-semibold mb-4">No Saves Yet</h2>
          <p className="text-vercel-gray-400 mb-2">
            Upload saves from your device to see them here
          </p>
          <p className="text-sm text-vercel-gray-500">
            Use the UPLOAD button on your paired device to sync save files
          </p>
        </div>
      ) : (
        <div className="border border-vercel-gray-800 rounded-lg p-6">
          <div className="flex justify-between items-center mb-6">
            <h2 className="text-2xl font-semibold">My Saves</h2>
            <span className="text-sm text-vercel-gray-400">
              {saves.length} {saves.length === 1 ? 'file' : 'files'}
            </span>
          </div>
          <div className="space-y-3">
            {saves.map((save, index) => (
              <div 
                key={`${save.filePath}-${index}`} 
                className="border border-vercel-gray-800 rounded-lg p-4 hover:border-vercel-gray-700 transition-colors"
              >
                <div className="flex justify-between items-start mb-2">
                  <div className="flex-1 min-w-0">
                    <h3 className="font-semibold text-lg mb-1 truncate">{save.fileName}</h3>
                    <p className="text-sm text-vercel-gray-400 truncate">{save.filePath}</p>
                  </div>
                  <div className="text-right ml-4">
                    <p className="text-sm text-vercel-gray-300 font-medium">
                      {formatFileSize(save.fileSize)}
                    </p>
                  </div>
                </div>
                <div className="flex justify-between items-center text-sm">
                  <div className="flex items-center gap-4">
                    <span className="text-vercel-gray-400">
                      From: <span className="text-vercel-gray-300">{save.device.name}</span>
                    </span>
                    <span className="text-vercel-gray-500">•</span>
                    <span className="text-vercel-gray-400">
                      {save.device.deviceType}
                    </span>
                  </div>
                  <span className="text-vercel-gray-500">
                    {new Intl.DateTimeFormat('en-US', {
                      dateStyle: 'medium',
                      timeStyle: 'short',
                    }).format(new Date(save.uploadedAt))}
                  </span>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}

export default function DashboardPage() {
  const router = useRouter()
  const [activeTab, setActiveTab] = useState<'devices' | 'saves'>('devices')
  const [devices, setDevices] = useState<Device[]>([])
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

  const logout = () => {
    localStorage.removeItem('token')
    localStorage.removeItem('user')
    router.push('/')
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-vercel-black flex items-center justify-center">
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
        <div className="mb-8">
          <h1 className="text-4xl font-bold mb-2">Dashboard</h1>
          <p className="text-vercel-gray-400">Manage your devices and save files</p>
        </div>

        {error && (
          <div 
            className="bg-red-500/10 border border-red-500/50 text-red-400 px-4 py-3 rounded-lg mb-6"
            role="alert"
            aria-live="polite"
          >
            {error}
          </div>
        )}

        {/* Tabs */}
        <div className="border-b border-vercel-gray-800 mb-8">
          <nav className="flex gap-8" aria-label="Dashboard tabs">
            <button
              onClick={() => setActiveTab('devices')}
              className={`pb-4 px-1 border-b-2 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-vercel-blue-500 focus-visible:ring-offset-2 focus-visible:ring-offset-vercel-black ${
                activeTab === 'devices'
                  ? 'border-vercel-white text-vercel-white font-medium'
                  : 'border-transparent text-vercel-gray-400 hover:text-vercel-white'
              }`}
              aria-selected={activeTab === 'devices'}
              role="tab"
            >
              My Devices
            </button>
            <button
              onClick={() => setActiveTab('saves')}
              className={`pb-4 px-1 border-b-2 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-vercel-blue-500 focus-visible:ring-offset-2 focus-visible:ring-offset-vercel-black ${
                activeTab === 'saves'
                  ? 'border-vercel-white text-vercel-white font-medium'
                  : 'border-transparent text-vercel-gray-400 hover:text-vercel-white'
              }`}
              aria-selected={activeTab === 'saves'}
              role="tab"
            >
              My Saves
            </button>
          </nav>
        </div>

        {/* Tab Content */}
        <div role="tabpanel">
          {activeTab === 'devices' && (
            <div className="space-y-6">
              <Link
                href="/dashboard/devices"
                className="block border border-vercel-gray-800 rounded-lg p-6 hover:border-vercel-gray-700 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-vercel-blue-500 focus-visible:ring-offset-2 focus-visible:ring-offset-vercel-black"
              >
                <h2 className="text-2xl font-semibold mb-2">Manage Devices</h2>
                <p className="text-vercel-gray-400 mb-4">
                  Add new devices or manage existing ones
                </p>
                <span className="text-vercel-blue-400 hover:text-vercel-blue-300 font-medium">
                  Go to Devices →
                </span>
              </Link>

              {devices.length > 0 && (
                <div className="border border-vercel-gray-800 rounded-lg p-6">
                  <h3 className="text-xl font-semibold mb-4">Your Devices</h3>
                  <div className="space-y-4">
                    {devices.slice(0, 3).map((device) => (
                      <div key={device.id} className="border border-vercel-gray-800 rounded-lg p-4">
                        <div className="flex justify-between items-start mb-2">
                          <div>
                            <h4 className="font-semibold text-lg">{device.name}</h4>
                            <p className="text-sm text-vercel-gray-400">{device.deviceType}</p>
                          </div>
                          <span className={`text-sm ${
                            device.isActive ? 'text-green-400' : 'text-vercel-gray-500'
                          }`}>
                            {device.isActive ? 'Active' : 'Inactive'}
                          </span>
                        </div>
                        <p className="text-sm text-vercel-gray-500">
                          Last sync: {device.lastSyncAt
                            ? new Intl.DateTimeFormat('en-US', {
                                dateStyle: 'medium',
                                timeStyle: 'short',
                              }).format(new Date(device.lastSyncAt))
                            : 'Never'}
                        </p>
                      </div>
                    ))}
                    {devices.length > 3 && (
                      <Link
                        href="/dashboard/devices"
                        className="block text-center text-vercel-gray-400 hover:text-vercel-white transition-colors py-2"
                      >
                        View all {devices.length} devices →
                      </Link>
                    )}
                  </div>
                </div>
              )}
            </div>
          )}

          {activeTab === 'saves' && (
            <SavesTab />
          )}
        </div>
      </main>
    </div>
  )
}
