'use client'

/**
 * =============================================================================
 * Devices Example Page
 * =============================================================================
 *
 * This is a minimal example showing how to use the useDevices hook
 * to build a device management interface.
 *
 * Key concepts demonstrated:
 * 1. Loading states with useAuth and useDevices
 * 2. Displaying device list
 * 3. Pairing new devices
 * 4. Deleting devices
 * 5. Error handling
 *
 * Feel free to copy this as a starting point for your redesign!
 */

import { useState } from 'react'
import Link from 'next/link'
import { useAuth, useDevices } from '@/hooks'
import type { Device } from '@/types'

export default function DevicesExamplePage() {
  // ==========================================================================
  // Hooks
  // ==========================================================================

  // Auth hook - handles authentication check and redirect
  const { isAuthenticated, isLoading: authLoading, logout } = useAuth()

  // Devices hook - handles all device data and operations
  const {
    devices,
    isLoading: devicesLoading,
    error,
    pairDevice,
    isPairing,
    pairingError,
    pairingSuccess,
    deleteDevice,
    isDeleting,
  } = useDevices()

  // ==========================================================================
  // Local State
  // ==========================================================================

  const [pairingCode, setPairingCode] = useState('')

  // ==========================================================================
  // Handlers
  // ==========================================================================

  const handlePair = async () => {
    const success = await pairDevice(pairingCode)
    if (success) {
      setPairingCode('') // Clear input on success
    }
  }

  const handleDelete = async (deviceId: string, deviceName: string) => {
    if (!confirm(`Delete "${deviceName}"?`)) return
    await deleteDevice(deviceId)
  }

  // ==========================================================================
  // Loading State
  // ==========================================================================

  if (authLoading || devicesLoading) {
    return (
      <div className="min-h-screen bg-vercel-black flex items-center justify-center">
        <div className="text-vercel-white text-xl">Loading...</div>
      </div>
    )
  }

  // If not authenticated, useAuth will redirect - show nothing
  if (!isAuthenticated) {
    return null
  }

  // ==========================================================================
  // Render
  // ==========================================================================

  return (
    <div className="min-h-screen bg-vercel-black text-vercel-white p-8">
      {/* Header */}
      <div className="max-w-4xl mx-auto">
        <div className="flex items-center justify-between mb-8">
          <div>
            <h1 className="text-3xl font-bold">Devices Example</h1>
            <p className="text-vercel-gray-400 mt-1">
              Minimal example using the <code className="text-vercel-blue-400">useDevices</code> hook
            </p>
          </div>
          <div className="flex gap-4">
            <Link
              href="/examples/saves"
              className="text-vercel-blue-400 hover:text-vercel-blue-300"
            >
              Saves Example →
            </Link>
            <button
              onClick={logout}
              className="text-vercel-gray-400 hover:text-white"
            >
              Logout
            </button>
          </div>
        </div>

        {/* Error Display */}
        {error && (
          <div className="bg-red-500/10 border border-red-500/50 text-red-400 p-4 rounded-lg mb-6">
            {error.message}
          </div>
        )}

        {/* Main Content Grid */}
        <div className="grid md:grid-cols-2 gap-8">
          {/* ================================================================
              SECTION 1: Pair a Device
              ================================================================ */}
          <div className="border border-vercel-gray-800 rounded-lg p-6">
            <h2 className="text-xl font-semibold mb-4">Pair a Device</h2>

            {/* Code Input */}
            <div className="space-y-4">
              <div>
                <label className="block text-sm text-vercel-gray-400 mb-2">
                  Enter 6-character code
                </label>
                <input
                  type="text"
                  value={pairingCode}
                  onChange={(e) =>
                    setPairingCode(
                      e.target.value.toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 6)
                    )
                  }
                  onKeyDown={(e) => {
                    if (e.key === 'Enter' && pairingCode.length === 6 && !isPairing) {
                      handlePair()
                    }
                  }}
                  placeholder="ABC123"
                  maxLength={6}
                  className="w-full bg-vercel-black border border-vercel-gray-700 rounded-lg px-4 py-3 text-2xl font-mono tracking-widest text-center focus:outline-none focus:ring-2 focus:ring-vercel-blue-500"
                />
              </div>

              {/* Pairing Error */}
              {pairingError && (
                <p className="text-red-400 text-sm">{pairingError}</p>
              )}

              {/* Pairing Success */}
              {pairingSuccess && (
                <p className="text-green-400 text-sm">
                  Code linked! Device will appear when it syncs.
                </p>
              )}

              {/* Pair Button */}
              <button
                onClick={handlePair}
                disabled={pairingCode.length !== 6 || isPairing}
                className="w-full bg-white text-black font-semibold py-3 rounded-lg hover:bg-gray-200 disabled:bg-vercel-gray-800 disabled:text-vercel-gray-500 disabled:cursor-not-allowed transition-colors"
              >
                {isPairing ? 'Pairing...' : 'Pair Device'}
              </button>
            </div>
          </div>

          {/* ================================================================
              SECTION 2: Device List
              ================================================================ */}
          <div className="border border-vercel-gray-800 rounded-lg p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-xl font-semibold">Your Devices</h2>
              <span className="text-sm text-vercel-gray-400">
                {devices.length} device{devices.length !== 1 ? 's' : ''}
              </span>
            </div>

            {devices.length === 0 ? (
              <p className="text-vercel-gray-500 text-center py-8">
                No devices paired yet
              </p>
            ) : (
              <ul className="space-y-3">
                {devices.map((device) => (
                  <DeviceCard
                    key={device.id}
                    device={device}
                    onDelete={() => handleDelete(device.id, device.name)}
                    isDeleting={isDeleting === device.id}
                  />
                ))}
              </ul>
            )}
          </div>
        </div>

        {/* ================================================================
            CODE EXAMPLE
            ================================================================ */}
        <div className="mt-12 border border-vercel-gray-800 rounded-lg p-6">
          <h2 className="text-xl font-semibold mb-4">How to use this hook</h2>
          <pre className="bg-vercel-gray-900 rounded-lg p-4 overflow-x-auto text-sm">
            <code className="text-vercel-gray-300">{`import { useAuth, useDevices } from '@/hooks'
import type { Device } from '@/types'

function MyDevicesPage() {
  // Auth check with auto-redirect
  const { isAuthenticated, isLoading: authLoading } = useAuth()

  // Get devices + all operations
  const {
    devices,           // Device[]
    isLoading,         // boolean
    error,             // Error | null

    // Pairing
    pairDevice,        // (code: string) => Promise<boolean>
    isPairing,         // boolean
    pairingError,      // string | null
    pairingSuccess,    // boolean

    // Deletion
    deleteDevice,      // (deviceId: string) => Promise<boolean>
    isDeleting,        // string | null (device ID being deleted)
  } = useDevices()

  if (authLoading || isLoading) return <Loading />

  return (
    <div>
      {devices.map(device => (
        <div key={device.id}>{device.name}</div>
      ))}
    </div>
  )
}`}</code>
          </pre>
        </div>
      </div>
    </div>
  )
}

// =============================================================================
// Device Card Component
// =============================================================================

interface DeviceCardProps {
  device: Device
  onDelete: () => void
  isDeleting: boolean
}

function DeviceCard({ device, onDelete, isDeleting }: DeviceCardProps) {
  return (
    <li className="border border-vercel-gray-800 rounded-lg p-4 hover:border-vercel-gray-700 transition-colors">
      <div className="flex items-start justify-between">
        <div className="min-w-0 flex-1">
          <h3 className="font-semibold truncate">{device.name}</h3>
          <p className="text-sm text-vercel-gray-400">{device.deviceType}</p>
          <p className="text-xs text-vercel-gray-500 mt-1">
            Last sync:{' '}
            {device.lastSyncAt
              ? new Date(device.lastSyncAt).toLocaleDateString()
              : 'Never'}
          </p>
        </div>
        <div className="flex items-center gap-3 ml-4">
          <span
            className={`text-xs ${device.isActive ? 'text-green-400' : 'text-vercel-gray-500'
              }`}
          >
            {device.isActive ? 'Active' : 'Inactive'}
          </span>
          <button
            onClick={onDelete}
            disabled={isDeleting}
            className="text-red-400 hover:text-red-300 text-sm disabled:opacity-50"
          >
            {isDeleting ? '...' : 'Delete'}
          </button>
        </div>
      </div>
    </li>
  )
}
