import { NextResponse } from 'next/server'

/**
 * Standard API response format
 */
export interface ApiResponse<T = any> {
  success: boolean
  data?: T
  error?: string
  message?: string
}

/**
 * SWR fetcher with authentication
 * Handles token from localStorage and redirects on 401
 */
export async function fetcher<T = any>(url: string): Promise<T> {
  const token = typeof window !== 'undefined' ? localStorage.getItem('token') : null

  if (!token) {
    throw new Error('No authentication token')
  }

  const response = await fetch(url, {
    headers: {
      'Authorization': `Bearer ${token}`,
    },
  })

  if (response.status === 401) {
    // Redirect to login on unauthorized
    if (typeof window !== 'undefined') {
      localStorage.removeItem('token')
      localStorage.removeItem('user')
      window.location.href = '/auth/login'
    }
    throw new Error('Unauthorized')
  }

  if (!response.ok) {
    throw new Error(`HTTP error! status: ${response.status}`)
  }

  const data: ApiResponse<T> = await response.json()

  if (!data.success) {
    throw new Error(data.error || 'Request failed')
  }

  return data.data as T
}

/**
 * Create a success response
 */
export function successResponse<T>(data: T, message?: string) {
  return NextResponse.json({
    success: true,
    data,
    message,
  } as ApiResponse<T>)
}

/**
 * Create an error response
 */
export function errorResponse(error: string, status: number = 400) {
  return NextResponse.json({
    success: false,
    error,
  } as ApiResponse, { status })
}

/**
 * Create an unauthorized response
 */
export function unauthorizedResponse(message: string = 'Unauthorized') {
  return errorResponse(message, 401)
}

/**
 * Create a not found response
 */
export function notFoundResponse(message: string = 'Not found') {
  return errorResponse(message, 404)
}

/**
 * Create a server error response
 */
export function serverErrorResponse(message: string = 'Internal server error') {
  return errorResponse(message, 500)
}

/**
 * Validate required fields in request body
 */
export function validateRequiredFields(body: any, fields: string[]): string | null {
  for (const field of fields) {
    if (!body[field]) {
      return `Missing required field: ${field}`
    }
  }
  return null
}

/**
 * Generate a funky random device name
 * Returns names like "Cosmic Gizmo", "Stellar Widget", "Nebula Device", etc.
 */
export function generateDeviceName(deviceType?: string): string {
  const adjectives = [
    'Cosmic', 'Stellar', 'Nebula', 'Quantum', 'Galactic', 'Astro', 'Lunar', 'Solar',
    'Electric', 'Neon', 'Cyber', 'Digital', 'Virtual', 'Hyper', 'Ultra', 'Mega',
    'Turbo', 'Super', 'Epic', 'Legendary', 'Mystic', 'Ancient', 'Crystal', 'Golden',
    'Silver', 'Platinum', 'Diamond', 'Ruby', 'Sapphire', 'Emerald', 'Amber', 'Jade',
    'Frost', 'Flame', 'Thunder', 'Storm', 'Shadow', 'Phantom', 'Ghost', 'Spirit',
    'Wild', 'Fierce', 'Bold', 'Swift', 'Rapid', 'Blazing', 'Frozen', 'Eternal'
  ]

  const nouns = [
    'Gizmo', 'Widget', 'Device', 'Gadget', 'Thing', 'Machine', 'Unit', 'Module',
    'Console', 'Station', 'Hub', 'Node', 'Core', 'Engine', 'Drive', 'System',
    'Beast', 'Warrior', 'Knight', 'Guardian', 'Champion', 'Hero', 'Legend', 'Myth',
    'Phoenix', 'Dragon', 'Tiger', 'Eagle', 'Wolf', 'Falcon', 'Hawk', 'Lion',
    'Star', 'Comet', 'Planet', 'Moon', 'Sun', 'Orb', 'Sphere', 'Cube',
    'Blade', 'Shield', 'Sword', 'Bow', 'Arrow', 'Spear', 'Axe', 'Hammer'
  ]

  const randomAdjective = adjectives[Math.floor(Math.random() * adjectives.length)]
  const randomNoun = nouns[Math.floor(Math.random() * nouns.length)]

  // Add a random number suffix for extra uniqueness (1-9999)
  const randomNum = Math.floor(Math.random() * 9999) + 1

  return `${randomAdjective} ${randomNoun} ${randomNum}`
}
