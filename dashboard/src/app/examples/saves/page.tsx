'use client'

/**
 * =============================================================================
 * Saves Example Page
 * =============================================================================
 *
 * This is a minimal example showing how to use the useSaves hook
 * to build a save file management interface.
 *
 * Key concepts demonstrated:
 * 1. Loading states with useAuth and useSaves
 * 2. Displaying save file list
 * 3. Downloading saves
 * 4. Deleting saves with confirmation
 * 5. Changing sync strategy
 * 6. Using utility functions for formatting
 *
 * Feel free to copy this as a starting point for your redesign!
 */

import Link from 'next/link'
import { useAuth, useSaves } from '@/hooks'
import type { Save, SyncStrategy } from '@/types'

export default function SavesExamplePage() {
  // ==========================================================================
  // Hooks
  // ==========================================================================

  // Auth hook - handles authentication check and redirect
  const { isAuthenticated, isLoading: authLoading, logout } = useAuth()

  // Saves hook - handles all save data and operations
  const {
    saves,
    count,
    isLoading: savesLoading,
    error,

    // Download
    downloadSave,
    isDownloading,

    // Delete
    requestDelete,
    cancelDelete,
    deleteConfirmId,
    deleteSave,
    isDeleting,

    // Sync Strategy
    setSyncStrategy,
    isUpdatingStrategy,

    // Utilities
    formatFileSize,
    formatRelativeTime,
    formatShortDateTime,
  } = useSaves()

  // ==========================================================================
  // Loading State
  // ==========================================================================

  if (authLoading || savesLoading) {
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
            <h1 className="text-3xl font-bold">Saves Example</h1>
            <p className="text-vercel-gray-400 mt-1">
              Minimal example using the <code className="text-vercel-blue-400">useSaves</code> hook
            </p>
          </div>
          <div className="flex gap-4">
            <Link
              href="/examples/devices"
              className="text-vercel-blue-400 hover:text-vercel-blue-300"
            >
              ← Devices Example
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

        {/* ================================================================
            SAVE LIST
            ================================================================ */}
        <div className="border border-vercel-gray-800 rounded-lg p-6">
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-xl font-semibold">Your Save Files</h2>
            <span className="text-sm text-vercel-gray-400">
              {count} save{count !== 1 ? 's' : ''}
            </span>
          </div>

          {saves.length === 0 ? (
            <p className="text-vercel-gray-500 text-center py-12">
              No saves yet. Upload some from your device!
            </p>
          ) : (
            <ul className="space-y-4">
              {saves.map((save) => (
                <SaveCard
                  key={save.id}
                  save={save}
                  // Download
                  onDownload={() => downloadSave(save.saveKey, save.displayName)}
                  isDownloading={isDownloading === save.saveKey}
                  // Delete
                  isConfirming={deleteConfirmId === save.id}
                  onRequestDelete={() => requestDelete(save.id)}
                  onCancelDelete={cancelDelete}
                  onConfirmDelete={() => deleteSave(save.id)}
                  isDeleting={isDeleting === save.id}
                  // Sync Strategy
                  onSetStrategy={(strategy) => setSyncStrategy(save.id, strategy)}
                  isUpdatingStrategy={isUpdatingStrategy === save.id}
                  // Utils
                  formatFileSize={formatFileSize}
                  formatRelativeTime={formatRelativeTime}
                  formatShortDateTime={formatShortDateTime}
                />
              ))}
            </ul>
          )}
        </div>

        {/* ================================================================
            CODE EXAMPLE
            ================================================================ */}
        <div className="mt-12 border border-vercel-gray-800 rounded-lg p-6">
          <h2 className="text-xl font-semibold mb-4">How to use this hook</h2>
          <pre className="bg-vercel-gray-900 rounded-lg p-4 overflow-x-auto text-sm">
            <code className="text-vercel-gray-300">{`import { useAuth, useSaves } from '@/hooks'
import type { Save, SyncStrategy } from '@/types'

function MySavesPage() {
  // Auth check with auto-redirect
  const { isAuthenticated, isLoading: authLoading } = useAuth()

  // Get saves + all operations
  const {
    saves,             // Save[]
    count,             // number
    isLoading,         // boolean
    error,             // Error | null

    // Download
    downloadSave,      // (saveKey, fileName, deviceId?) => Promise<boolean>
    isDownloading,     // string | null (save key being downloaded)

    // Delete (two-step: request -> confirm)
    requestDelete,     // (saveId: string) => void
    cancelDelete,      // () => void
    deleteConfirmId,   // string | null
    deleteSave,        // (saveId: string) => Promise<boolean>
    isDeleting,        // string | null

    // Sync Strategy
    setSyncStrategy,   // (saveId, strategy) => Promise<boolean>
    isUpdatingStrategy,// string | null

    // Built-in formatters
    formatFileSize,    // (bytes: number) => string
    formatRelativeTime,// (isoString: string) => string
    formatShortDateTime,// (isoString: string) => string
  } = useSaves()

  if (authLoading || isLoading) return <Loading />

  return (
    <div>
      {saves.map(save => (
        <div key={save.id}>
          <span>{save.displayName}</span>
          <span>{formatFileSize(save.fileSize)}</span>
          <button onClick={() => downloadSave(save.saveKey, save.displayName)}>
            Download
          </button>
        </div>
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
// Save Card Component
// =============================================================================

interface SaveCardProps {
  save: Save
  // Download
  onDownload: () => void
  isDownloading: boolean
  // Delete
  isConfirming: boolean
  onRequestDelete: () => void
  onCancelDelete: () => void
  onConfirmDelete: () => void
  isDeleting: boolean
  // Sync Strategy
  onSetStrategy: (strategy: SyncStrategy) => void
  isUpdatingStrategy: boolean
  // Utils
  formatFileSize: (bytes: number) => string
  formatRelativeTime: (isoString: string) => string
  formatShortDateTime: (isoString: string) => string
}

function SaveCard({
  save,
  onDownload,
  isDownloading,
  isConfirming,
  onRequestDelete,
  onCancelDelete,
  onConfirmDelete,
  isDeleting,
  onSetStrategy,
  isUpdatingStrategy,
  formatFileSize,
  formatRelativeTime,
  formatShortDateTime,
}: SaveCardProps) {
  return (
    <li className="border border-vercel-gray-800 rounded-lg p-4 hover:border-vercel-gray-700 transition-colors">
      {/* Header Row */}
      <div className="flex items-start justify-between gap-4">
        <div className="min-w-0 flex-1">
          <h3 className="font-semibold truncate">{save.displayName}</h3>
          <p className="text-sm text-vercel-gray-400">
            {formatFileSize(save.fileSize)} • Modified: {formatShortDateTime(save.lastModifiedAt)}
          </p>
          {save.latestVersionDevice && (
            <p className="text-xs text-vercel-gray-500 mt-1">
              Latest on: {save.latestVersionDevice.name}
            </p>
          )}
        </div>

        {/* Action Buttons */}
        <div className="flex items-center gap-2">
          <button
            onClick={onDownload}
            disabled={isDownloading}
            className="px-3 py-1.5 text-sm border border-vercel-gray-700 rounded hover:bg-vercel-gray-800 disabled:opacity-50"
          >
            {isDownloading ? '...' : '↓'}
          </button>

          {isConfirming ? (
            <div className="flex items-center gap-1">
              <button
                onClick={onConfirmDelete}
                disabled={isDeleting}
                className="px-3 py-1.5 text-sm bg-red-500/20 border border-red-500/50 text-red-400 rounded hover:bg-red-500/30 disabled:opacity-50"
              >
                {isDeleting ? '...' : 'Confirm'}
              </button>
              <button
                onClick={onCancelDelete}
                className="px-3 py-1.5 text-sm border border-vercel-gray-700 rounded hover:bg-vercel-gray-800"
              >
                Cancel
              </button>
            </div>
          ) : (
            <button
              onClick={onRequestDelete}
              className="px-3 py-1.5 text-sm border border-red-900/50 text-red-400 rounded hover:bg-red-500/10"
            >
              Delete
            </button>
          )}
        </div>
      </div>

      {/* Sync Strategy Toggle */}
      <div className="mt-4 pt-4 border-t border-vercel-gray-800">
        <div className="flex items-center gap-3">
          <span className="text-xs text-vercel-gray-400">Sync mode:</span>
          <div className="inline-flex rounded border border-vercel-gray-700 bg-vercel-gray-900 p-0.5">
            <SyncButton
              label="Shared"
              isActive={save.syncStrategy === 'shared'}
              onClick={() => onSetStrategy('shared')}
              disabled={isUpdatingStrategy}
              title="One version syncs to all devices"
            />
            <SyncButton
              label="Per Device"
              isActive={save.syncStrategy === 'per_device'}
              onClick={() => onSetStrategy('per_device')}
              disabled={isUpdatingStrategy}
              title="Each device keeps its own version"
            />
          </div>
        </div>
      </div>

      {/* Device Locations */}
      {save.locations.length > 0 && (
        <div className="mt-4 pt-4 border-t border-vercel-gray-800">
          <p className="text-xs text-vercel-gray-500 uppercase mb-2">
            Locations ({save.locations.length})
          </p>
          <ul className="space-y-1">
            {save.locations.slice(0, 3).map((loc) => (
              <li
                key={loc.id}
                className="text-xs text-vercel-gray-400 truncate"
                title={loc.localPath}
              >
                <span className="text-vercel-gray-500">{loc.deviceName}:</span>{' '}
                {loc.localPath}
                {loc.isLatest && (
                  <span className="text-green-400 ml-1">(latest)</span>
                )}
              </li>
            ))}
            {save.locations.length > 3 && (
              <li className="text-xs text-vercel-gray-500">
                +{save.locations.length - 3} more
              </li>
            )}
          </ul>
        </div>
      )}
    </li>
  )
}

// =============================================================================
// Sync Button Component
// =============================================================================

interface SyncButtonProps {
  label: string
  isActive: boolean
  onClick: () => void
  disabled: boolean
  title: string
}

function SyncButton({ label, isActive, onClick, disabled, title }: SyncButtonProps) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      title={title}
      className={`px-2 py-1 text-xs font-medium rounded transition-colors disabled:opacity-50 ${isActive
          ? 'bg-vercel-blue-600 text-white'
          : 'text-vercel-gray-300 hover:bg-vercel-gray-800'
        }`}
    >
      {label}
    </button>
  )
}
