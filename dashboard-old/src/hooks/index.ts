/**
 * =============================================================================
 * RetroSync Hooks
 * =============================================================================
 *
 * This module exports all custom hooks for the RetroSync dashboard.
 * Import hooks from '@/hooks' for cleaner imports.
 *
 * @example
 * import { useAuth, useDevices, useSaves } from '@/hooks'
 *
 * function MyComponent() {
 *   const { isAuthenticated, logout } = useAuth()
 *   const { devices, isLoading: devicesLoading } = useDevices()
 *   const { saves, isLoading: savesLoading } = useSaves()
 *
 *   // ...
 * }
 */

// Authentication hook
export { useAuth, type UseAuthOptions, type UseAuthReturn } from './useAuth'

// Devices hook
export { useDevices, type UseDevicesOptions, type UseDevicesReturn } from './useDevices'

// Saves hook
export { useSaves, type UseSavesOptions, type UseSavesReturn } from './useSaves'
