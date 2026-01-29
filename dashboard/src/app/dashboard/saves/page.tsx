'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import useSWR, { mutate } from 'swr'
import { fetcher } from '@/lib/utils'

interface SaveLocation {
  id: string
  deviceId: string
  deviceName: string
  deviceType: string
  localPath: string
  syncEnabled: boolean
  isLatest: boolean
  latestModifiedAt: string | null
  modifiedAt: string | null
  uploadedAt: string | null
}

interface Save {
  id: string
  saveKey: string
  displayName: string
  fileSize: number
  uploadedAt: string
  lastModifiedAt: string
  locations: SaveLocation[]
  latestVersionDevice: {
    id: string
    name: string
    deviceType: string
  } | null
}

interface SavesResponse {
  saves: Save[]
  count: number
}

const DownloadIcon = () => (
  <svg
    aria-hidden="true"
    viewBox="0 0 20 20"
    className="h-4 w-4"
  >
    <path
      d="M10 2.5a.75.75 0 0 1 .75.75v7.19l2.22-2.22a.75.75 0 1 1 1.06 1.06l-3.5 3.5a.75.75 0 0 1-1.06 0l-3.5-3.5a.75.75 0 0 1 1.06-1.06l2.22 2.22V3.25A.75.75 0 0 1 10 2.5Z"
      className="fill-current"
    />
    <path
      d="M4.25 12.5a.75.75 0 0 1 .75.75v1.5h10v-1.5a.75.75 0 0 1 1.5 0v2.25a.75.75 0 0 1-.75.75h-11.5a.75.75 0 0 1-.75-.75v-2.25a.75.75 0 0 1 .75-.75Z"
      className="fill-current"
    />
  </svg>
)

const TrashIcon = () => (
  <svg
    aria-hidden="true"
    viewBox="0 0 20 20"
    className="h-4 w-4"
  >
    <path
      d="M7.5 2.75A1.75 1.75 0 0 1 9.25 1h1.5A1.75 1.75 0 0 1 12.5 2.75V3h3.25a.75.75 0 0 1 0 1.5h-.57l-.63 10.03A1.75 1.75 0 0 1 12.81 16H7.19a1.75 1.75 0 0 1-1.74-1.47L4.82 4.5h-.57a.75.75 0 0 1 0-1.5H7.5v-.25Zm1.75.25h1.5v-.25a.25.25 0 0 0-.25-.25h-1.5a.25.25 0 0 0-.25.25V3Z"
      className="fill-current"
    />
    <path
      d="M8.75 7.25a.75.75 0 0 1 .75.75v4.5a.75.75 0 0 1-1.5 0v-4.5a.75.75 0 0 1 .75-.75Zm2.5 0a.75.75 0 0 1 .75.75v4.5a.75.75 0 0 1-1.5 0v-4.5a.75.75 0 0 1 .75-.75Z"
      className="fill-current"
    />
  </svg>
)

export default function SavesPage() {
  const router = useRouter()
  const [error, setError] = useState('')
  const [deleting, setDeleting] = useState<string | null>(null)
  const [deleteConfirm, setDeleteConfirm] = useState<string | null>(null)
  const [downloading, setDownloading] = useState<string | null>(null)
  const [toggling, setToggling] = useState<string | null>(null) // saveLocationId being toggled

  // Check authentication
  useEffect(() => {
    const token = localStorage.getItem('token')
    if (!token) {
      router.push('/auth/login')
    }
  }, [router])

  // Fetch saves with SWR
  const { data, error: swrError, isLoading } = useSWR<SavesResponse>(
    typeof window !== 'undefined' && localStorage.getItem('token') ? '/api/saves' : null,
    fetcher,
    {
      onError: (err) => {
        if (err instanceof Error && err.message !== 'Unauthorized') {
          setError(err.message)
        }
      },
    }
  )

  const saves = data?.saves || []

  // Sanity check: timestamps should be reasonable (between 2020 and 1 year in the future)
  // Some devices send CRC values as timestamps due to stat failures, causing dates like 2055+
  const MIN_VALID_YEAR = 2020
  const MAX_VALID_YEAR = new Date().getFullYear() + 1

  const isValidTimestamp = (dt: Date): boolean => {
    const year = dt.getFullYear()
    return year >= MIN_VALID_YEAR && year <= MAX_VALID_YEAR
  }

  const formatShortDateTime = (isoString: string): string => {
    const dt = new Date(isoString)
    if (Number.isNaN(dt.getTime())) return ''

    // If timestamp is invalid (e.g., year 2055 from corrupted data), show "Unknown"
    if (!isValidTimestamp(dt)) {
      return 'Unknown'
    }

    // Example output: "12/3/2024 12:26 PM"
    // Using 4-digit year to avoid confusion with corrupted timestamps (e.g., 2102 showing as "02")
    const formatted = new Intl.DateTimeFormat('en-US', {
      month: 'numeric',
      day: 'numeric',
      year: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
      hour12: true,
    }).format(dt)

    // Remove the default comma between date and time for a tighter layout
    return formatted.replace(',', '')
  }

  const formatRelativeOrShort = (isoString: string): string => {
    const dt = new Date(isoString)
    if (Number.isNaN(dt.getTime())) return ''

    // If timestamp is invalid, return "Unknown"
    if (!isValidTimestamp(dt)) {
      return 'Unknown'
    }

    const now = new Date()
    const diffMs = now.getTime() - dt.getTime()

    // If somehow the timestamp is in the future, show "just now"
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

    // 24+ hours ago, show the compact absolute date/time
    return formatShortDateTime(isoString)
  }

  const formatFileSize = (bytes: number): string => {
    if (bytes === 0) return '0 B'
    const k = 1024
    const sizes = ['B', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i]
  }

  const handleDelete = async (saveId: string) => {
    if (deleteConfirm !== saveId) {
      setDeleteConfirm(saveId)
      return
    }

    setDeleting(saveId)
    try {
      const token = localStorage.getItem('token')
      // Note: This still uses filePath for backward compatibility, but we'll need to update the API
      // For now, we'll use saveKey as filePath
      const save = saves.find((s) => s.id === saveId)
      if (!save) {
        setError('Save not found')
        return
      }

      const response = await fetch(
        `/api/saves?saveId=${encodeURIComponent(save.id)}`,
        {
          method: 'DELETE',
          headers: {
            'Authorization': `Bearer ${token}`,
          },
        }
      )

      const data = await response.json()

      if (data.success) {
        // Revalidate saves list
        mutate('/api/saves')
        setDeleteConfirm(null)
        setError('')
      } else {
        setError(data.error || 'Failed to delete save')
      }
    } catch (err) {
      setError('Failed to delete save')
    } finally {
      setDeleting(null)
    }
  }

  const buildDownloadKey = (filePath: string, deviceId?: string | null) =>
    deviceId ? `${filePath}::${deviceId}` : filePath

  const handleDownload = async (filePath: string, fileName: string, deviceId?: string | null) => {
    const downloadKey = buildDownloadKey(filePath, deviceId || undefined)
    setDownloading(downloadKey)
    try {
      const token = localStorage.getItem('token')
      const params = new URLSearchParams({ filePath })
      if (deviceId) {
        params.append('deviceId', deviceId)
      }
      const res = await fetch(`/api/saves/download?${params.toString()}`, {
        headers: {
          'Authorization': `Bearer ${token}`,
        },
      })

      const body = await res.json()
      if (!res.ok || !body?.success) {
        setError(body?.error || 'Failed to generate download link')
        return
      }

      const url: string | undefined = body?.data?.url
      if (!url) {
        setError('Download link was empty')
        return
      }

      // Prefer opening in same tab so browser download UX works consistently
      window.location.href = url
      setError('')
    } catch (err) {
      setError(`Failed to download ${fileName}`)
    } finally {
      setDownloading(null)
    }
  }

  const handleToggleSync = async (saveLocationId: string, currentValue: boolean) => {
    setToggling(saveLocationId)
    try {
      const token = localStorage.getItem('token')
      const res = await fetch('/api/saves/toggle-sync', {
        method: 'PATCH',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          saveLocationId,
          syncEnabled: !currentValue,
        }),
      })

      const body = await res.json()
      if (!res.ok || !body?.success) {
        setError(body?.error || 'Failed to toggle sync')
        return
      }

      // Revalidate saves list
      mutate('/api/saves')
      setError('')
    } catch (err) {
      setError('Failed to toggle sync')
    } finally {
      setToggling(null)
    }
  }

  if (isLoading) {
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
        <div className="mb-8">
          <h1 className="text-4xl font-bold mb-2">My Saves</h1>
          <p className="text-vercel-gray-400">View and manage your uploaded save files</p>
        </div>

        {(error || swrError) && (
          <div
            className="bg-red-500/10 border border-red-500/50 text-red-400 px-4 py-3 rounded-lg mb-6"
            role="alert"
            aria-live="polite"
          >
            {error || (swrError instanceof Error ? swrError.message : 'Failed to fetch saves')}
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
          <div className="border border-vercel-gray-800 rounded-lg p-6 sm:p-8">
            <div className="flex justify-between items-center mb-6">
              <h2 className="text-2xl font-semibold">Your Save Files</h2>
              <span className="text-sm text-vercel-gray-400">
                {saves.length} {saves.length === 1 ? 'file' : 'files'}
              </span>
            </div>
            <div className="space-y-3">
              {saves.map((save) => (
                <div
                  key={save.id}
                  className="border border-vercel-gray-800 rounded-lg p-4 hover:border-vercel-gray-700 transition-colors"
                >
                  <div className="flex justify-between items-start mb-3">
                    <div className="flex-1 min-w-0">
                      <h3 className="font-semibold text-lg mb-1 truncate">{save.displayName}</h3>
                      <p className="text-sm text-vercel-gray-400 mb-2">
                        {formatFileSize(save.fileSize)} •{' '}
                        <span>
                          Modified:{' '}
                          {formatShortDateTime(save.lastModifiedAt || save.uploadedAt)}
                        </span>
                        {save.uploadedAt && (
                          <>
                            {' '}
                            • <span>Uploaded: {formatRelativeOrShort(save.uploadedAt)}</span>
                          </>
                        )}
                      </p>
                    </div>
                    <div className="text-right ml-4 flex flex-col items-end gap-2">
                      {save.latestVersionDevice && (
                        <span className="text-xs text-vercel-gray-400">
                          Latest: {save.latestVersionDevice.name}
                        </span>
                      )}
                      <div className="flex items-center gap-2">
                        <button
                          onClick={() => handleDownload(save.saveKey, save.displayName)}
                          disabled={downloading === buildDownloadKey(save.saveKey)}
                          className="inline-flex items-center justify-center px-3 py-1.5 text-xs rounded-md border border-vercel-gray-700 bg-vercel-gray-900 hover:bg-vercel-gray-800 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                        >
                          <DownloadIcon />
                          <span className="sr-only">
                            {downloading === buildDownloadKey(save.saveKey) ? 'Downloading…' : 'Download'}
                          </span>
                        </button>
                        <button
                          onClick={() => handleDelete(save.id)}
                          disabled={deleting === save.id}
                          className="inline-flex items-center justify-center px-3 py-1.5 text-xs rounded-md border border-red-900/70 text-red-400 hover:bg-red-500/10 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                        >
                          <TrashIcon />
                          <span className="sr-only">
                            {deleting === save.id
                              ? 'Deleting…'
                              : deleteConfirm === save.id
                                ? 'Click again to confirm delete'
                                : 'Delete'}
                          </span>
                        </button>
                      </div>
                    </div>
                  </div>

                  {/* Device locations with sync toggles */}
                  <div className="space-y-2 mt-4 pt-4 border-t border-vercel-gray-800">
                    <p className="text-xs font-semibold text-vercel-gray-400 uppercase mb-2">
                      Device Locations
                    </p>
                    {(() => {
                      // First, sort locations so the newest one is at the top.
                      const sortedLocations = [...save.locations].sort((a, b) => {
                        // Prefer the backend's "isLatest" hint when it's consistent…
                        if (a.isLatest && !b.isLatest) return -1
                        if (!a.isLatest && b.isLatest) return 1

                        // …but fall back to timestamps so we still get a stable order
                        // even if multiple locations are flagged as latest.
                        const aTime = new Date(
                          a.modifiedAt ||
                          a.uploadedAt ||
                          a.latestModifiedAt ||
                          save.lastModifiedAt ||
                          save.uploadedAt
                        ).getTime()
                        const bTime = new Date(
                          b.modifiedAt ||
                          b.uploadedAt ||
                          b.latestModifiedAt ||
                          save.lastModifiedAt ||
                          save.uploadedAt
                        ).getTime()
                        return bTime - aTime
                      })

                      // Only the first (newest) location should visually appear as "latest".
                      const latestLocationId = sortedLocations[0]?.id

                      return sortedLocations.map((location) => {
                        const isVisuallyLatest = location.id === latestLocationId

                        return (
                          <div
                            key={location.id}
                            className={`flex items-center justify-between p-2 rounded ${isVisuallyLatest
                              ? 'bg-green-500/10 border border-green-500/30'
                              : 'bg-vercel-gray-900/50'
                              }`}
                          >
                            <div className="flex-1 min-w-0">
                              <div className="flex items-center gap-2 mb-1">
                                {isVisuallyLatest && (
                                  <span className="text-green-400 font-semibold text-xs">✓ LATEST</span>
                                )}
                                <span className="text-sm font-medium text-vercel-gray-300">
                                  {location.deviceName}
                                </span>
                                <button
                                  type="button"
                                  onClick={() =>
                                    handleDownload(save.saveKey, save.displayName, location.deviceId)
                                  }
                                  disabled={
                                    downloading === buildDownloadKey(save.saveKey, location.deviceId)
                                  }
                                  className="inline-flex h-6 w-6 items-center justify-center rounded-full border border-vercel-gray-700 bg-vercel-gray-900 text-[10px] text-vercel-gray-200 hover:bg-vercel-gray-800 disabled:opacity-50 disabled:cursor-not-allowed"
                                  aria-label={`Download save for ${location.deviceName} (${location.deviceType})`}
                                  title={`Download save for ${location.deviceName} (${location.deviceType})`}
                                >
                                  ↓
                                </button>
                              </div>
                              <p className="text-xs text-vercel-gray-400 truncate">{location.localPath}</p>
                              {(location.modifiedAt ||
                                location.uploadedAt ||
                                location.latestModifiedAt ||
                                save.lastModifiedAt ||
                                save.uploadedAt) && (
                                  <p
                                    className={`text-xs mt-1 ${isVisuallyLatest ? 'text-green-400/80' : 'text-vercel-gray-400'
                                      }`}
                                  >
                                    <>
                                      Modified:{' '}
                                      {formatShortDateTime(
                                        location.modifiedAt ||
                                        location.latestModifiedAt ||
                                        save.lastModifiedAt ||
                                        save.uploadedAt
                                      )}
                                    </>
                                    {location.uploadedAt && (
                                      <>
                                        {' '}
                                        • Uploaded: {formatRelativeOrShort(location.uploadedAt)}
                                      </>
                                    )}
                                  </p>
                                )}
                            </div>
                            <div className="ml-4 flex items-center gap-3">
                              <label className="flex items-center gap-2 cursor-pointer">
                                <input
                                  type="checkbox"
                                  checked={location.syncEnabled}
                                  onChange={() => handleToggleSync(location.id, location.syncEnabled)}
                                  disabled={toggling === location.id}
                                  className="w-4 h-4 rounded border-vercel-gray-600 bg-vercel-gray-800 text-vercel-blue-600 focus:ring-2 focus:ring-vercel-blue-500 focus:ring-offset-2 focus:ring-offset-vercel-black disabled:opacity-50 disabled:cursor-not-allowed"
                                />
                                <span className="text-xs text-vercel-gray-300">
                                  {location.syncEnabled ? 'Sync enabled' : 'Sync disabled'}
                                </span>
                              </label>
                            </div>
                          </div>
                        )
                      })
                    })()}
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}
      </main>
    </div>
  )
}
