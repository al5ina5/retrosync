import { NextRequest } from 'next/server'
import { prisma } from '@/lib/prisma'
import { getUserFromRequest } from '@/lib/auth'
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/utils'
import { canAddDevice } from '@/lib/planLimits'
import { z } from 'zod'
import { checkRateLimit } from '@/lib/security'

const pairSchema = z.object({
  code: z
    .string()
    .length(6, 'Code must be 6 characters')
    .regex(/^[A-Z0-9]+$/i, 'Code must be alphanumeric'),
})

/**
 * POST /api/devices/pair
 * User links code to their account (Netflix-style)
 * Authentication required
 */
export async function POST(request: NextRequest) {
  try {
    const rl = checkRateLimit(request, {
      windowMs: 60 * 1000,
      max: 30,
      keyPrefix: 'pair',
    })
    if (!rl.allowed) {
      return errorResponse('Too many pairing attempts, please try again shortly.', 429)
    }

    // Authenticate user
    const user = getUserFromRequest(request)
    if (!user) {
      return unauthorizedResponse()
    }

    const body = await request.json()

    // Validate input
    const validation = pairSchema.safeParse(body)
    if (!validation.success) {
      return errorResponse(validation.error.errors[0].message)
    }

    const { code } = validation.data

    // Find pairing code (uppercase for consistency)
    const pairingCode = await prisma.pairingCode.findUnique({
      where: { code: code.toUpperCase() },
    })

    if (!pairingCode) {
      return errorResponse('Invalid code', 404)
    }

    // Check if code is expired
    if (new Date() > pairingCode.expiresAt) {
      return errorResponse('Code has expired. Please get a new code from your device.')
    }

    // Check if code is already used
    if (pairingCode.used) {
      return errorResponse('Code has already been used')
    }

    // Check if code is already linked to a different user
    if (pairingCode.userId && pairingCode.userId !== user.userId) {
      return errorResponse('Code is already linked to another account')
    }

    const deviceLimit = await canAddDevice(user.userId)
    if (!deviceLimit.allowed) {
      return errorResponse(deviceLimit.reason || 'Device limit reached', 402)
    }

    // Link code to user
    await prisma.pairingCode.update({
      where: { id: pairingCode.id },
      data: {
        userId: user.userId,
      },
    })

    return successResponse({
      code: pairingCode.code,
      linked: true,
    }, 'Code linked to your account. Your device will connect automatically.')
  } catch (error) {
    console.error('Pair error:', error)
    return errorResponse('Failed to link code', 500)
  }
}
