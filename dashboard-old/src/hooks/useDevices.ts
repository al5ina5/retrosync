'use client'

import { useState, useCallback } from 'react'
import useSWR, { mutate } from 'swr'
import { fetcher } from '@/lib/utils'
import type { Device, DevicesResponse } from '@/types'

/**
 * =============================================================================
 * useDevices Hook
 * =============================================================================
 *
 * A hook for fetching and managing paired devices.
 * Provides automatic data fetching, caching, and mutation functions
 * for common device operations.
 *
 * @example Basic usage - display device list
 * ```tsx
 * function DeviceList() {
 *   const { devices, isLoading, error } = useDevices()
 *
 *   if (isLoading) return <Spinner />
 *   if (error) return <Error message={error.message} />
 *
 *   return (
 *     <ul>
 *       {devices.map(device => (
 *         <li key={device.id}>{device.name}</li>
 *       ))}
 *     </ul>
 *   )
 * }
 * ```
 *
 * @example With pairing flow
 * ```tsx
 * function DevicePairing() {
 *   const { devices, pairDevice, isPairing, pairingError } = useDevices()
 *   const [code, setCode] = useState('')
 *
 *   const handlePair = async () => {
 *     const success = await pairDevice(code)
 *     if (success) {
 *       setCode('')
 *       alert('Device paired!')
 *     }
 *   }
 *
 *   return (
 *     <div>
 *       <input value={code} onChange={e => setCode(e.target.value)} />
 *       <button onClick={handlePair} disabled={isPairing}>
 *         {isPairing ? 'Pairing...' : 'Pair Device'}
 *       </button>
 *       {pairingError && <p className="error">{pairingError}</p>}
 *     </div>
 *   )
 * }
 * ```
 *
 * @example Delete a device
 * ```tsx
 * function DeviceItem({ device }: { device: Device }) {
 *   const { deleteDevice, isDeleting } = useDevices()
 *
 *   const handleDelete = async () => {
 *     if (confirm('Delete this device?')) {
 *       await deleteDevice(device.id)
 *     }
 *   }
 *
 *   return (
 *     <div>
 *       <span>{device.name}</span>
 *       <button onClick={handleDelete} disabled={isDeleting === device.id}>
 *         {isDeleting === device.id ? 'Deleting...' : 'Delete'}
 *       </button>
 *     </div>
 *   )
 * }
 * ```
 *
 * @param options.refreshInterval - Auto-refresh interval in ms (0 to disable)
 * @param options.onPairingSuccess - Callback when a device is successfully paired
 *
 * @returns Device data and mutation functions
 */

export interface UseDevicesOptions {
  /**
   * Auto-refresh interval in milliseconds
   * Set to 0 to disable auto-refresh
   * @default 0
   */
  refreshInterval?: number

  /**
   * Callback fired when a device is successfully paired
   */
  onPairingSuccess?: () => void

  /**
   * Callback fired when a device is successfully deleted
   */
  onDeleteSuccess?: (deviceId: string) => void
}

export interface UseDevicesReturn {
  /** List of paired devices */
  devices: Device[]

  /** Whether the initial fetch is in progress */
  isLoading: boolean

  /** Error from the fetch, if any */
  error: Error | null

  /** Whether a background revalidation is in progress */
  isValidating: boolean

  /** Manually refresh the device list */
  refresh: () => Promise<void>

  // === Pairing ===

  /** Pair a new device using a 6-character code */
  pairDevice: (code: string) => Promise<boolean>

  /** Whether a pairing operation is in progress */
  isPairing: boolean

  /** Error from the last pairing attempt */
  pairingError: string | null

  /** Whether pairing was recently successful (for UI feedback) */
  pairingSuccess: boolean

  /** Clear pairing success state */
  clearPairingSuccess: () => void

  // === Deletion ===

  /** Delete a device by ID */
  deleteDevice: (deviceId: string) => Promise<boolean>

  /** ID of the device currently being deleted, or null */
  isDeleting: string | null

  /** Error from the last delete attempt */
  deleteError: string | null
}

export function useDevices(options: UseDevicesOptions = {}): UseDevicesReturn {
  const { refreshInterval = 0, onPairingSuccess, onDeleteSuccess } = options

  // Pairing state
  const [isPairing, setIsPairing] = useState(false)
  const [pairingError, setPairingError] = useState<string | null>(null)
  const [pairingSuccess, setPairingSuccess] = useState(false)

  // Delete state
  const [isDeleting, setIsDeleting] = useState<string | null>(null)
  const [deleteError, setDeleteError] = useState<string | null>(null)

  // Fetch devices with SWR
  const {
    data,
    error,
    isLoading,
    isValidating,
  } = useSWR<DevicesResponse>(
    typeof window !== 'undefined' && localStorage.getItem('token')
      ? '/api/devices'
      : null,
    fetcher,
    {
      refreshInterval: pairingSuccess ? 2000 : refreshInterval,
      onError: (err) => {
        // Don't show error for unauthorized (will redirect)
        if (err instanceof Error && err.message === 'Unauthorized') {
          return
        }
      },
    }
  )

  const devices = data?.devices || []

  /**
   * Manually refresh the device list
   */
  const refresh = useCallback(async () => {
    await mutate('/api/devices')
  }, [])

  /**
   * Pair a new device using a 6-character code
   */
  const pairDevice = useCallback(
    async (code: string): Promise<boolean> => {
      // Validate code format
      if (code.length !== 6) {
        setPairingError('Code must be 6 characters')
        return false
      }

      setIsPairing(true)
      setPairingError(null)
      setPairingSuccess(false)

      try {
        const token = localStorage.getItem('token')
        const response = await fetch('/api/devices/pair', {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${token}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ code }),
        })

        const data = await response.json()

        if (data.success) {
          setPairingSuccess(true)
          onPairingSuccess?.()

          // Auto-clear success state after 30 seconds
          setTimeout(() => {
            setPairingSuccess(false)
          }, 30000)

          return true
        } else {
          setPairingError(data.error || 'Failed to link code')
          return false
        }
      } catch (err) {
        setPairingError('Failed to link code')
        return false
      } finally {
        setIsPairing(false)
      }
    },
    [onPairingSuccess]
  )

  /**
   * Clear pairing success state
   */
  const clearPairingSuccess = useCallback(() => {
    setPairingSuccess(false)
  }, [])

  /**
   * Delete a device by ID
   */
  const deleteDevice = useCallback(
    async (deviceId: string): Promise<boolean> => {
      setIsDeleting(deviceId)
      setDeleteError(null)

      try {
        const token = localStorage.getItem('token')
        const response = await fetch(`/api/devices?id=${deviceId}`, {
          method: 'DELETE',
          headers: {
            Authorization: `Bearer ${token}`,
          },
        })

        const data = await response.json()

        if (data.success) {
          // Revalidate the device list
          await mutate('/api/devices')
          onDeleteSuccess?.(deviceId)
          return true
        } else {
          setDeleteError(data.error || 'Failed to delete device')
          return false
        }
      } catch (err) {
        setDeleteError('Failed to delete device')
        return false
      } finally {
        setIsDeleting(null)
      }
    },
    [onDeleteSuccess]
  )

  return {
    devices,
    isLoading,
    error: error || null,
    isValidating,
    refresh,

    pairDevice,
    isPairing,
    pairingError,
    pairingSuccess,
    clearPairingSuccess,

    deleteDevice,
    isDeleting,
    deleteError,
  }
}

export default useDevices
