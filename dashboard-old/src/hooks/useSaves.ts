'use client'

import { useState, useCallback, useMemo } from 'react'
import useSWR, { mutate } from 'swr'
import { fetcher } from '@/lib/utils'
import type { Save, SavesResponse, SyncStrategy } from '@/types'

/**
 * =============================================================================
 * useSaves Hook
 * =============================================================================
 *
 * A hook for fetching and managing game save files.
 * Provides automatic data fetching, caching, and mutation functions
 * for common save operations like download, delete, and sync strategy changes.
 *
 * @example Basic usage - display save list
 * ```tsx
 * function SaveList() {
 *   const { saves, isLoading, error } = useSaves()
 *
 *   if (isLoading) return <Spinner />
 *   if (error) return <Error message={error.message} />
 *
 *   return (
 *     <ul>
 *       {saves.map(save => (
 *         <li key={save.id}>
 *           {save.displayName} ({formatFileSize(save.fileSize)})
 *         </li>
 *       ))}
 *     </ul>
 *   )
 * }
 * ```
 *
 * @example With download functionality
 * ```tsx
 * function SaveItem({ save }: { save: Save }) {
 *   const { downloadSave, isDownloading } = useSaves()
 *
 *   const handleDownload = () => {
 *     downloadSave(save.saveKey, save.displayName)
 *   }
 *
 *   return (
 *     <div>
 *       <span>{save.displayName}</span>
 *       <button
 *         onClick={handleDownload}
 *         disabled={isDownloading === save.saveKey}
 *       >
 *         {isDownloading === save.saveKey ? 'Downloading...' : 'Download'}
 *       </button>
 *     </div>
 *   )
 * }
 * ```
 *
 * @example Change sync strategy
 * ```tsx
 * function SyncStrategyToggle({ save }: { save: Save }) {
 *   const { setSyncStrategy, isUpdatingStrategy } = useSaves()
 *
 *   const toggle = () => {
 *     const newStrategy = save.syncStrategy === 'shared' ? 'per_device' : 'shared'
 *     setSyncStrategy(save.id, newStrategy)
 *   }
 *
 *   return (
 *     <button onClick={toggle} disabled={isUpdatingStrategy === save.id}>
 *       {save.syncStrategy === 'shared' ? 'Sync All' : 'Per Device'}
 *     </button>
 *   )
 * }
 * ```
 *
 * @example Delete with confirmation
 * ```tsx
 * function DeleteButton({ save }: { save: Save }) {
 *   const { deleteSave, isDeleting, deleteConfirmId, requestDelete } = useSaves()
 *
 *   const handleClick = () => {
 *     // First click sets confirmation, second click deletes
 *     if (deleteConfirmId === save.id) {
 *       deleteSave(save.id)
 *     } else {
 *       requestDelete(save.id)
 *     }
 *   }
 *
 *   return (
 *     <button onClick={handleClick} disabled={isDeleting === save.id}>
 *       {isDeleting === save.id
 *         ? 'Deleting...'
 *         : deleteConfirmId === save.id
 *         ? 'Click to Confirm'
 *         : 'Delete'}
 *     </button>
 *   )
 * }
 * ```
 *
 * @returns Save data and mutation functions
 */

export interface UseSavesOptions {
  /**
   * Auto-refresh interval in milliseconds
   * Set to 0 to disable auto-refresh
   * @default 0
   */
  refreshInterval?: number

  /**
   * Callback fired when a save is successfully deleted
   */
  onDeleteSuccess?: (saveId: string) => void

  /**
   * Callback fired when sync strategy is changed
   */
  onStrategyChange?: (saveId: string, strategy: SyncStrategy) => void
}

export interface UseSavesReturn {
  /** List of save files */
  saves: Save[]

  /** Total count of saves */
  count: number

  /** Whether the initial fetch is in progress */
  isLoading: boolean

  /** Error from the fetch, if any */
  error: Error | null

  /** Whether a background revalidation is in progress */
  isValidating: boolean

  /** Manually refresh the saves list */
  refresh: () => Promise<void>

  // === Download ===

  /** Download a save file (opens download in browser) */
  downloadSave: (saveKey: string, fileName: string, deviceId?: string) => Promise<boolean>

  /** Save key currently being downloaded, or null */
  isDownloading: string | null

  /** Error from the last download attempt */
  downloadError: string | null

  // === Delete ===

  /** Request deletion (first step - sets confirmation) */
  requestDelete: (saveId: string) => void

  /** Cancel deletion request */
  cancelDelete: () => void

  /** ID of save awaiting delete confirmation, or null */
  deleteConfirmId: string | null

  /** Delete a save file (call after confirmation) */
  deleteSave: (saveId: string) => Promise<boolean>

  /** ID of save currently being deleted, or null */
  isDeleting: string | null

  /** Error from the last delete attempt */
  deleteError: string | null

  // === Sync Strategy ===

  /** Set the sync strategy for a save */
  setSyncStrategy: (saveId: string, strategy: SyncStrategy) => Promise<boolean>

  /** ID of save whose strategy is being updated, or null */
  isUpdatingStrategy: string | null

  /** Error from the last strategy update */
  strategyError: string | null

  // === Utility Functions ===

  /** Format file size in human-readable format */
  formatFileSize: (bytes: number) => string

  /** Format timestamp relative to now or as short date */
  formatRelativeTime: (isoString: string) => string

  /** Format timestamp as short date/time */
  formatShortDateTime: (isoString: string) => string
}

/**
 * Format file size in human-readable format
 */
function formatFileSize(bytes: number): string {
  if (bytes === 0) return '0 B'
  const k = 1024
  const sizes = ['B', 'KB', 'MB', 'GB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return Math.round((bytes / Math.pow(k, i)) * 100) / 100 + ' ' + sizes[i]
}

/**
 * Check if a timestamp is valid (between 2020 and 1 year from now)
 */
function isValidTimestamp(dt: Date): boolean {
  const MIN_VALID_YEAR = 2020
  const MAX_VALID_YEAR = new Date().getFullYear() + 1
  const year = dt.getFullYear()
  return year >= MIN_VALID_YEAR && year <= MAX_VALID_YEAR
}

/**
 * Format timestamp as short date/time (e.g., "12/3/2024 12:26 PM")
 */
function formatShortDateTime(isoString: string): string {
  const dt = new Date(isoString)
  if (Number.isNaN(dt.getTime())) return ''

  if (!isValidTimestamp(dt)) {
    return 'Unknown'
  }

  const formatted = new Intl.DateTimeFormat('en-US', {
    month: 'numeric',
    day: 'numeric',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
    hour12: true,
  }).format(dt)

  return formatted.replace(',', '')
}

/**
 * Format timestamp relative to now or as short date
 */
function formatRelativeTime(isoString: string): string {
  const dt = new Date(isoString)
  if (Number.isNaN(dt.getTime())) return ''

  if (!isValidTimestamp(dt)) {
    return 'Unknown'
  }

  const now = new Date()
  const diffMs = now.getTime() - dt.getTime()

  if (diffMs < 0) {
    return 'just now'
  }

  const diffSeconds = Math.floor(diffMs / 1000)
  const diffMinutes = Math.floor(diffSeconds / 60)
  const diffHours = Math.floor(diffMinutes / 60)

  if (diffSeconds < 60) {
    return 'just now'
  }

  if (diffMinutes < 60) {
    const roundedMinutes = Math.max(1, diffMinutes)
    return `about ${roundedMinutes} minute${roundedMinutes === 1 ? '' : 's'} ago`
  }

  if (diffHours < 24) {
    const roundedHours = Math.max(1, diffHours)
    return `about ${roundedHours} hour${roundedHours === 1 ? '' : 's'} ago`
  }

  return formatShortDateTime(isoString)
}

export function useSaves(options: UseSavesOptions = {}): UseSavesReturn {
  const { refreshInterval = 0, onDeleteSuccess, onStrategyChange } = options

  // Download state
  const [isDownloading, setIsDownloading] = useState<string | null>(null)
  const [downloadError, setDownloadError] = useState<string | null>(null)

  // Delete state
  const [deleteConfirmId, setDeleteConfirmId] = useState<string | null>(null)
  const [isDeleting, setIsDeleting] = useState<string | null>(null)
  const [deleteError, setDeleteError] = useState<string | null>(null)

  // Sync strategy state
  const [isUpdatingStrategy, setIsUpdatingStrategy] = useState<string | null>(null)
  const [strategyError, setStrategyError] = useState<string | null>(null)

  // Fetch saves with SWR
  const { data, error, isLoading, isValidating } = useSWR<SavesResponse>(
    typeof window !== 'undefined' && localStorage.getItem('token')
      ? '/api/saves'
      : null,
    fetcher,
    {
      refreshInterval,
      onError: (err) => {
        if (err instanceof Error && err.message === 'Unauthorized') {
          return
        }
      },
    }
  )

  const saves = data?.saves || []
  const count = data?.count || 0

  /**
   * Manually refresh the saves list
   */
  const refresh = useCallback(async () => {
    await mutate('/api/saves')
  }, [])

  /**
   * Build a unique download key for tracking state
   */
  const buildDownloadKey = useCallback((saveKey: string, deviceId?: string) => {
    return deviceId ? `${saveKey}::${deviceId}` : saveKey
  }, [])

  /**
   * Download a save file
   */
  const downloadSave = useCallback(
    async (saveKey: string, fileName: string, deviceId?: string): Promise<boolean> => {
      const downloadKey = buildDownloadKey(saveKey, deviceId)
      setIsDownloading(downloadKey)
      setDownloadError(null)

      try {
        const token = localStorage.getItem('token')
        const params = new URLSearchParams({ filePath: saveKey })
        if (deviceId) {
          params.append('deviceId', deviceId)
        }

        const res = await fetch(`/api/saves/download?${params.toString()}`, {
          headers: {
            Authorization: `Bearer ${token}`,
          },
        })

        const body = await res.json()
        if (!res.ok || !body?.success) {
          setDownloadError(body?.error || 'Failed to generate download link')
          return false
        }

        const url: string | undefined = body?.data?.url
        if (!url) {
          setDownloadError('Download link was empty')
          return false
        }

        // Trigger browser download
        window.location.href = url
        return true
      } catch (err) {
        setDownloadError(`Failed to download ${fileName}`)
        return false
      } finally {
        setIsDownloading(null)
      }
    },
    [buildDownloadKey]
  )

  /**
   * Request deletion (first step - sets confirmation)
   */
  const requestDelete = useCallback((saveId: string) => {
    setDeleteConfirmId(saveId)
    setDeleteError(null)
  }, [])

  /**
   * Cancel deletion request
   */
  const cancelDelete = useCallback(() => {
    setDeleteConfirmId(null)
  }, [])

  /**
   * Delete a save file
   */
  const deleteSave = useCallback(
    async (saveId: string): Promise<boolean> => {
      setIsDeleting(saveId)
      setDeleteError(null)

      try {
        const token = localStorage.getItem('token')
        const response = await fetch(`/api/saves?saveId=${encodeURIComponent(saveId)}`, {
          method: 'DELETE',
          headers: {
            Authorization: `Bearer ${token}`,
          },
        })

        const data = await response.json()

        if (data.success) {
          await mutate('/api/saves')
          setDeleteConfirmId(null)
          onDeleteSuccess?.(saveId)
          return true
        } else {
          setDeleteError(data.error || 'Failed to delete save')
          return false
        }
      } catch (err) {
        setDeleteError('Failed to delete save')
        return false
      } finally {
        setIsDeleting(null)
      }
    },
    [onDeleteSuccess]
  )

  /**
   * Set the sync strategy for a save
   */
  const setSyncStrategy = useCallback(
    async (saveId: string, strategy: SyncStrategy): Promise<boolean> => {
      setIsUpdatingStrategy(saveId)
      setStrategyError(null)

      try {
        const token = localStorage.getItem('token')
        const res = await fetch('/api/saves/set-sync-strategy', {
          method: 'PATCH',
          headers: {
            Authorization: `Bearer ${token}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ saveId, syncStrategy: strategy }),
        })

        const body = await res.json()
        if (!res.ok || !body?.success) {
          setStrategyError(body?.error || 'Failed to set sync strategy')
          return false
        }

        await mutate('/api/saves')
        onStrategyChange?.(saveId, strategy)
        return true
      } catch (err) {
        setStrategyError('Failed to set sync strategy')
        return false
      } finally {
        setIsUpdatingStrategy(null)
      }
    },
    [onStrategyChange]
  )

  // Memoize utility functions to maintain referential equality
  const utils = useMemo(
    () => ({
      formatFileSize,
      formatRelativeTime,
      formatShortDateTime,
    }),
    []
  )

  return {
    saves,
    count,
    isLoading,
    error: error || null,
    isValidating,
    refresh,

    downloadSave,
    isDownloading,
    downloadError,

    requestDelete,
    cancelDelete,
    deleteConfirmId,
    deleteSave,
    isDeleting,
    deleteError,

    setSyncStrategy,
    isUpdatingStrategy,
    strategyError,

    ...utils,
  }
}

export default useSaves
