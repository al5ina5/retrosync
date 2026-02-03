import { NextRequest } from 'next/server'
import { prisma } from '@/lib/prisma'
import { getUserFromRequest, generatePairingCode } from '@/lib/auth'
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/utils'
import { canAddDevice } from '@/lib/planLimits'
import { z } from 'zod'
import { checkRateLimit } from '@/lib/security'

const pairByDeviceIdSchema = z.object({
  deviceId: z
    .string()
    .length(6, 'Device ID must be 6 digits')
    .regex(/^\d{6}$/, 'Device ID must be numeric'),
})

export async function POST(request: NextRequest) {
  try {
    // Authenticate user
    const user = getUserFromRequest(request)
    if (!user) {
      return unauthorizedResponse()
    }

    const rl = checkRateLimit(request, {
      windowMs: 60 * 1000,
      max: 30,
      keyPrefix: 'pair-by-id',
    })
    if (!rl.allowed) {
      return errorResponse('Too many pairing attempts, please try again shortly.', 429)
    }

    const body = await request.json()

    // Validate input
    const validation = pairByDeviceIdSchema.safeParse(body)
    if (!validation.success) {
      return errorResponse(validation.error.errors[0].message)
    }

    const deviceLimit = await canAddDevice(user.userId)
    if (!deviceLimit.allowed) {
      return errorResponse(deviceLimit.reason || 'Device limit reached', 402)
    }

    const { deviceId } = validation.data

    // Check if there's already a pairing code for this device identifier that's not used
    const existingCode = await prisma.pairingCode.findFirst({
      where: {
        deviceIdentifier: deviceId,
        used: false,
        expiresAt: {
          gt: new Date(),
        },
      },
    })

    if (existingCode) {
      return successResponse({
        message: 'Pairing code already exists for this device',
        code: existingCode.code,
      }, 'Device code registered successfully')
    }

    // Generate 6-digit pairing code
    let code = generatePairingCode()
    let attempts = 0
    const maxAttempts = 10

    // Ensure code is unique
    while (attempts < maxAttempts) {
      const existing = await prisma.pairingCode.findUnique({
        where: { code },
      })

      if (!existing) {
        break
      }

      code = generatePairingCode()
      attempts++
    }

    if (attempts >= maxAttempts) {
      return errorResponse('Failed to generate unique pairing code', 500)
    }

    // Create pairing code (expires in 15 minutes) and associate with device identifier
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000)
    const pairingCode = await prisma.pairingCode.create({
      data: {
        code,
        userId: user.userId,
        deviceIdentifier: deviceId, // Store the 6-digit device ID
        expiresAt,
      },
    })

    return successResponse({
      message: 'Pairing code created. Device will detect it automatically.',
      code: pairingCode.code,
      deviceIdentifier: pairingCode.deviceIdentifier,
    }, 'Device code registered successfully')
  } catch (error) {
    console.error('Pair by device ID error:', error)
    return errorResponse('Failed to register device code', 500)
  }
}
