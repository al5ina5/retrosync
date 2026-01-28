import { NextRequest } from 'next/server'
import { Prisma } from '@prisma/client'
import { prisma } from '@/lib/prisma'
import { successResponse, errorResponse } from '@/lib/utils'
import { z } from 'zod'
import { randomBytes } from 'crypto'

const codeRequestSchema = z.object({
  deviceType: z.enum(['rg35xx', 'miyoo_flip', 'windows', 'mac', 'linux', 'other']).optional(),
})

/**
 * Generate a cryptographically strong 6-character alphanumeric code
 * using the same character set as before, but without Math.random.
 */
function generateSecureCode(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789' // Removed confusing chars (0, O, I, 1)
  const bytes = randomBytes(6)
  let code = ''
  for (let i = 0; i < 6; i++) {
    code += chars[bytes[i] % chars.length]
  }
  return code
}

/**
 * POST /api/devices/code
 * Device gets a unique code on launch (Netflix-style)
 * No authentication required
 */
export async function POST(request: NextRequest) {
  try {
    console.log('[CODE API] Request received')
    const body = await request.json().catch(() => ({}))
    console.log('[CODE API] Body:', JSON.stringify(body))

    const validation = codeRequestSchema.safeParse(body)
    if (!validation.success) {
      console.log('[CODE API] Validation failed:', validation.error.errors)
      return errorResponse(validation.error.errors[0].message)
    }

    const { deviceType } = validation.data || {}
    console.log('[CODE API] Device type:', deviceType)

    // Generate unique 6-character alphanumeric code (e.g., "ABC123")
    let code: string
    let attempts = 0
    const maxAttempts = 100

    do {
      code = generateSecureCode()
      attempts++

      const existing = await prisma.pairingCode.findUnique({
        where: { code },
      })

      if (!existing) {
        break
      }
    } while (attempts < maxAttempts)

    if (attempts >= maxAttempts) {
      console.error('[CODE API] Failed to generate unique code after', attempts, 'attempts')
      return errorResponse('Failed to generate unique code', 500)
    }

    console.log('[CODE API] Generated code:', code, 'after', attempts, 'attempts')

    // Create pairing code (expires in 15 minutes)
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000)

    // Create the pairing code using Prisma (nullable FKs are allowed)
    const codeUpper = code.toUpperCase() // Store uppercase for consistency
    let pairingCode
    try {
      pairingCode = await prisma.pairingCode.create({
        data: {
          code: codeUpper,
          userId: null,
          deviceId: null,
          expiresAt,
          used: false,
          deviceType: deviceType || 'other',
        },
      })
    } catch (insertError) {
      console.error('Insert error:', insertError)
      return errorResponse('Failed to create pairing code', 500)
    }

    console.log('[CODE API] Successfully created code:', pairingCode.code, 'expires at:', pairingCode.expiresAt)

    return successResponse(
      {
        code: pairingCode.code,
        expiresAt: pairingCode.expiresAt,
      },
      'Code generated successfully'
    )
  } catch (error) {
    console.error('Generate code error:', error)

    const isPrismaInit = error instanceof Prisma.PrismaClientInitializationError
    const isPrismaKnown = error instanceof Prisma.PrismaClientKnownRequestError
    const isPrismaOther =
      error instanceof Prisma.PrismaClientUnknownRequestError ||
      error instanceof Prisma.PrismaClientValidationError

    if (isPrismaInit) {
      return errorResponse('Database connection failed', 500)
    }
    if (isPrismaKnown || isPrismaOther) {
      return errorResponse('Database error', 500)
    }

    return errorResponse('Failed to generate code', 500)
  }
}
