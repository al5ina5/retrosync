import { NextRequest } from 'next/server'
import { prisma } from '@/lib/prisma'
import { verifyPassword, generateToken } from '@/lib/auth'
import { successResponse, errorResponse } from '@/lib/utils'
import { z } from 'zod'

const loginSchema = z.object({
  email: z.string().email('Invalid email address'),
  password: z.string().min(1, 'Password is required'),
})

// Simple in-memory tracking of failed login attempts per email to make brute-force
// more difficult without impacting normal users too much.
const failedLoginAttempts = new Map<
  string,
  {
    count: number
    lastAttempt: number
    lockedUntil?: number
  }
>()

const MAX_FAILED_ATTEMPTS = 5
const LOCKOUT_WINDOW_MS = 15 * 60 * 1000 // 15 minutes
const LOCKOUT_DURATION_MS = 5 * 60 * 1000 // 5 minutes

function isLocked(email: string): boolean {
  const entry = failedLoginAttempts.get(email)
  if (!entry || !entry.lockedUntil) return false
  if (entry.lockedUntil <= Date.now()) {
    failedLoginAttempts.delete(email)
    return false
  }
  return true
}

function recordFailedAttempt(email: string) {
  const now = Date.now()
  const entry = failedLoginAttempts.get(email)
  if (!entry) {
    failedLoginAttempts.set(email, { count: 1, lastAttempt: now })
    return
  }

  // Reset window if last attempt was long ago
  if (now - entry.lastAttempt > LOCKOUT_WINDOW_MS) {
    failedLoginAttempts.set(email, { count: 1, lastAttempt: now })
    return
  }

  entry.count += 1
  entry.lastAttempt = now

  if (entry.count >= MAX_FAILED_ATTEMPTS) {
    entry.lockedUntil = now + LOCKOUT_DURATION_MS
  }

  failedLoginAttempts.set(email, entry)
}

function clearFailedAttempts(email: string) {
  failedLoginAttempts.delete(email)
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()

    // Validate input
    const validation = loginSchema.safeParse(body)
    if (!validation.success) {
      return errorResponse(validation.error.errors[0].message)
    }

    const { email, password } = validation.data

    if (isLocked(email)) {
      return errorResponse('Too many failed login attempts. Please try again later.', 429)
    }

    // Find user
    const user = await prisma.user.findUnique({
      where: { email },
    })

    if (!user) {
      recordFailedAttempt(email)
      return errorResponse('Invalid email or password', 401)
    }

    // Verify password
    const isValid = await verifyPassword(password, user.passwordHash)
    if (!isValid) {
      recordFailedAttempt(email)
      return errorResponse('Invalid email or password', 401)
    }

    clearFailedAttempts(email)

    // Generate JWT token
    const token = generateToken({
      userId: user.id,
      email: user.email,
      type: 'user',
    })

    return successResponse(
      {
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
          subscriptionTier: user.subscriptionTier,
          createdAt: user.createdAt,
        },
        token,
      },
      'Login successful'
    )
  } catch (error) {
    console.error('Login error:', error)
    return errorResponse('Failed to login', 500)
  }
}
