'use client'

import { useState, useEffect, useCallback } from 'react'
import { useRouter } from 'next/navigation'
import type { AuthState } from '@/types'

/**
 * =============================================================================
 * useAuth Hook
 * =============================================================================
 *
 * A hook for managing authentication state in the dashboard.
 * Handles checking auth status, redirecting unauthenticated users,
 * and providing logout functionality.
 *
 * @example Basic usage - protect a page
 * ```tsx
 * function ProtectedPage() {
 *   const { isAuthenticated, isLoading, logout } = useAuth()
 *
 *   if (isLoading) return <LoadingSpinner />
 *   if (!isAuthenticated) return null // Will redirect automatically
 *
 *   return (
 *     <div>
 *       <h1>Welcome!</h1>
 *       <button onClick={logout}>Logout</button>
 *     </div>
 *   )
 * }
 * ```
 *
 * @example Disable auto-redirect (for public pages that optionally show user info)
 * ```tsx
 * function PublicPage() {
 *   const { isAuthenticated, token } = useAuth({ redirectOnUnauthenticated: false })
 *
 *   return (
 *     <div>
 *       {isAuthenticated ? <UserMenu /> : <LoginButton />}
 *     </div>
 *   )
 * }
 * ```
 *
 * @param options.redirectOnUnauthenticated - Whether to redirect to /auth/login if not authenticated (default: true)
 * @param options.redirectTo - Custom redirect path (default: '/auth/login')
 *
 * @returns Authentication state and actions
 */

export interface UseAuthOptions {
  /**
   * Whether to automatically redirect to login page if not authenticated
   * @default true
   */
  redirectOnUnauthenticated?: boolean

  /**
   * Custom path to redirect to when not authenticated
   * @default '/auth/login'
   */
  redirectTo?: string
}

export interface UseAuthReturn extends AuthState {
  /**
   * Log out the current user
   * Clears local storage and redirects to home page
   */
  logout: () => void

  /**
   * Get the current auth token
   * Useful for making authenticated API calls
   */
  getToken: () => string | null
}

export function useAuth(options: UseAuthOptions = {}): UseAuthReturn {
  const { redirectOnUnauthenticated = true, redirectTo = '/auth/login' } = options

  const router = useRouter()
  const [state, setState] = useState<AuthState>({
    isAuthenticated: false,
    isLoading: true,
    token: null,
  })

  // Check authentication status on mount
  useEffect(() => {
    const token = localStorage.getItem('token')

    if (token) {
      setState({
        isAuthenticated: true,
        isLoading: false,
        token,
      })
    } else {
      setState({
        isAuthenticated: false,
        isLoading: false,
        token: null,
      })

      // Redirect if enabled and not authenticated
      if (redirectOnUnauthenticated) {
        router.push(redirectTo)
      }
    }
  }, [router, redirectOnUnauthenticated, redirectTo])

  /**
   * Log out the current user
   */
  const logout = useCallback(() => {
    localStorage.removeItem('token')
    localStorage.removeItem('user')

    setState({
      isAuthenticated: false,
      isLoading: false,
      token: null,
    })

    router.push('/')
  }, [router])

  /**
   * Get the current auth token
   */
  const getToken = useCallback(() => {
    return localStorage.getItem('token')
  }, [])

  return {
    ...state,
    logout,
    getToken,
  }
}

export default useAuth
