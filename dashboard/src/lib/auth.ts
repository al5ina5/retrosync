import jwt, { SignOptions } from 'jsonwebtoken'
import bcrypt from 'bcryptjs'
import { NextRequest } from 'next/server'
import crypto from 'crypto'

// In production we require an explicit JWT secret. In non-production we allow a
// deterministic fallback to keep local/dev setups smooth while still avoiding
// accidental weak secrets in real deployments.
const JWT_SECRET =
  process.env.JWT_SECRET ||
  (process.env.NODE_ENV !== 'production'
    ? 'your-super-secret-jwt-key-change-this-in-development-only'
    : (() => {
      throw new Error('JWT_SECRET must be set in production')
    })())

export interface JWTPayload {
  userId: string
  email: string
  type: 'user' | 'device'
  deviceId?: string
}

/**
 * Hash a password
 */
export async function hashPassword(password: string): Promise<string> {
  return bcrypt.hash(password, 10)
}

/**
 * Verify a password
 */
export async function verifyPassword(password: string, hash: string): Promise<boolean> {
  return bcrypt.compare(password, hash)
}

/**
 * Generate a JWT token
 *
 * Default expiry is shorter to limit risk window; callers can override if needed.
 */
export function generateToken(payload: JWTPayload, expiresIn: string = '7d'): string {
  return jwt.sign(payload, JWT_SECRET, { expiresIn } as SignOptions)
}

/**
 * Verify a JWT token
 */
export function verifyToken(token: string): JWTPayload | null {
  try {
    return jwt.verify(token, JWT_SECRET) as JWTPayload
  } catch (error) {
    return null
  }
}

/**
 * Extract token from Authorization header
 */
export function extractToken(request: NextRequest): string | null {
  const authHeader = request.headers.get('authorization')
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return null
  }
  return authHeader.substring(7)
}

/**
 * Get user from request
 */
export function getUserFromRequest(request: NextRequest): JWTPayload | null {
  const token = extractToken(request)
  if (!token) {
    return null
  }
  return verifyToken(token)
}

/**
 * Generate a random API key
 */
export function generateApiKey(): string {
  return crypto.randomBytes(32).toString('hex')
}

/**
 * Generate a 6-digit pairing code
 */
export function generatePairingCode(): string {
  // Use cryptographically strong randomness instead of Math.random
  return crypto.randomInt(100000, 1000000).toString()
}

/**
 * Verify API key from request
 */
export function extractApiKey(request: NextRequest): string | null {
  const apiKey = request.headers.get('x-api-key')
  return apiKey
}
