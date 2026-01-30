/**
 * =============================================================================
 * RetroSync Shared Types
 * =============================================================================
 *
 * This file contains all shared TypeScript types used across the dashboard.
 * Import from '@/types' to use these types in your components and hooks.
 *
 * @example
 * import { Device, Save, SyncStrategy } from '@/types'
 */

// =============================================================================
// Device Types
// =============================================================================

/**
 * Represents a paired device (e.g., Miyoo Mini, Anbernic, etc.)
 *
 * @example
 * const device: Device = {
 *   id: 'clx123...',
 *   name: 'Cosmic Phoenix 42',
 *   deviceType: 'Miyoo Mini Plus',
 *   lastSyncAt: '2024-01-15T10:30:00Z',
 *   isActive: true,
 *   createdAt: '2024-01-01T00:00:00Z',
 * }
 */
export interface Device {
  /** Unique identifier (CUID) */
  id: string
  /** User-friendly device name (auto-generated or custom) */
  name: string
  /** Device model/type (e.g., "Miyoo Mini Plus", "Anbernic RG35XX") */
  deviceType: string
  /** ISO timestamp of last successful sync, or null if never synced */
  lastSyncAt: string | null
  /** Whether the device is currently active/online */
  isActive: boolean
  /** ISO timestamp when the device was first paired */
  createdAt: string
}

/**
 * API response shape for device list endpoint
 */
export interface DevicesResponse {
  devices: Device[]
}

// =============================================================================
// Save Types
// =============================================================================

/**
 * Sync strategy determines how saves are handled across multiple devices
 *
 * - `shared`: One version syncs to all devices (latest wins)
 * - `per_device`: Each device keeps its own version; all backed up, no cross-device sync
 */
export type SyncStrategy = 'shared' | 'per_device'

/**
 * Represents a save file location on a specific device
 * A single save can exist at multiple paths on multiple devices
 */
export interface SaveLocation {
  /** Unique identifier for this location */
  id: string
  /** Device ID this location belongs to */
  deviceId: string
  /** User-friendly device name */
  deviceName: string
  /** Device type/model */
  deviceType: string
  /** Local file path on the device */
  localPath: string
  /** Whether this device has the latest version */
  isLatest: boolean
  /** Timestamp of the latest modification (if this device has latest) */
  latestModifiedAt: string | null
  /** Timestamp when this device's version was last modified */
  modifiedAt: string | null
  /** Timestamp when this device last uploaded */
  uploadedAt: string | null
}

/**
 * Represents a game save file with all its versions and locations
 *
 * @example
 * const save: Save = {
 *   id: 'clx456...',
 *   saveKey: 'Pokemon Crystal.sav',
 *   displayName: 'Pokemon Crystal.sav',
 *   fileSize: 32768,
 *   uploadedAt: '2024-01-15T10:30:00Z',
 *   lastModifiedAt: '2024-01-15T10:25:00Z',
 *   syncStrategy: 'shared',
 *   locations: [...],
 *   latestVersionDevice: { id: '...', name: 'Cosmic Phoenix', deviceType: 'Miyoo' },
 * }
 */
export interface Save {
  /** Unique identifier (CUID) */
  id: string
  /** Unique key identifying this save (usually the filename) */
  saveKey: string
  /** Human-readable display name */
  displayName: string
  /** File size in bytes */
  fileSize: number
  /** ISO timestamp of last upload */
  uploadedAt: string
  /** ISO timestamp of last modification on any device */
  lastModifiedAt: string
  /** How this save is synced across devices */
  syncStrategy: SyncStrategy
  /** All locations/paths where this save exists */
  locations: SaveLocation[]
  /** Device that has the latest version, or null */
  latestVersionDevice: {
    id: string
    name: string
    deviceType: string
  } | null
}

/**
 * API response shape for saves list endpoint
 */
export interface SavesResponse {
  saves: Save[]
  count: number
}

// =============================================================================
// API Response Types
// =============================================================================

/**
 * Standard API response wrapper
 * All API endpoints return this shape for consistency
 *
 * @example
 * // Success response
 * { success: true, data: { devices: [...] } }
 *
 * // Error response
 * { success: false, error: 'Something went wrong' }
 */
export interface ApiResponse<T = unknown> {
  success: boolean
  data?: T
  error?: string
  message?: string
}

// =============================================================================
// Hook State Types
// =============================================================================

/**
 * Common state shape for data-fetching hooks
 * Provides consistent loading/error handling across all hooks
 */
export interface HookState<T> {
  /** The fetched data, or undefined if not yet loaded */
  data: T | undefined
  /** Whether the initial fetch is in progress */
  isLoading: boolean
  /** Error object if the fetch failed */
  error: Error | null
  /** Whether a background revalidation is in progress */
  isValidating: boolean
}

/**
 * User authentication state
 */
export interface AuthState {
  /** Whether the user is authenticated */
  isAuthenticated: boolean
  /** Whether we're still checking auth status */
  isLoading: boolean
  /** The auth token, or null if not authenticated */
  token: string | null
}
