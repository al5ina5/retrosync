import { NextRequest } from 'next/server'
import { prisma } from '@/lib/prisma'
import { generateApiKey } from '@/lib/auth'
import { successResponse, errorResponse, generateDeviceName } from '@/lib/utils'
import { z } from 'zod'
import { checkRateLimit } from '@/lib/security'

const autoPairSchema = z.object({
  deviceId: z
    .string()
    .length(6, 'Device ID must be 6 digits')
    .regex(/^\d{6}$/, 'Device ID must be numeric'),
})

/**
 * POST /api/devices/auto-pair
 * Simplified endpoint: Device polls this with its deviceId
 * If a pairing code exists for this deviceId, automatically complete pairing
 * and return API key. Otherwise, return not ready.
 */
export async function POST(request: NextRequest) {
  try {
    const rl = checkRateLimit(request, {
      windowMs: 60 * 1000,
      max: 60,
      keyPrefix: 'auto-pair',
    })
    if (!rl.allowed) {
      return errorResponse('Too many pairing checks, please slow down.', 429)
    }

    const body = await request.json()

    // Validate input
    const validation = autoPairSchema.safeParse(body)
    if (!validation.success) {
      return errorResponse(validation.error.errors[0].message)
    }

    const { deviceId } = validation.data

    // Check if device is already paired by looking for a used pairing code with this deviceIdentifier
    const usedPairingCode = await prisma.pairingCode.findFirst({
      where: {
        deviceIdentifier: deviceId,
        used: true,
      },
      include: {
        device: true,
      },
      orderBy: {
        usedAt: 'desc',
      },
    })

    if (usedPairingCode && usedPairingCode.device) {
      // Device already paired, return API key
      return successResponse({
        paired: true,
        apiKey: usedPairingCode.device.apiKey,
        device: {
          id: usedPairingCode.device.id,
          name: usedPairingCode.device.name,
          deviceType: usedPairingCode.device.deviceType,
        },
      }, 'Device already paired')
    }

    // Check if there's an unused pairing code for this deviceIdentifier
    const pairingCode = await prisma.pairingCode.findFirst({
      where: {
        deviceIdentifier: deviceId,
        used: false,
        expiresAt: {
          gt: new Date(),
        },
      },
      include: {
        user: {
          select: {
            id: true,
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
    })

    if (!pairingCode) {
      // No pairing code yet, device should keep waiting
      return successResponse({
        paired: false,
        ready: false,
      }, 'No pairing code found. Waiting for user to enter code on dashboard.')
    }

    // Pairing code found! Complete the pairing automatically
    const apiKey = generateApiKey()
    const deviceName = generateDeviceName(pairingCode.deviceType)

    // Create device
    const device = await prisma.device.create({
      data: {
        userId: pairingCode.userId,
        name: deviceName,
        deviceType: pairingCode.deviceType || 'other',
        apiKey,
        lastSyncAt: new Date(),
      },
    })

    // Mark pairing code as used
    await prisma.pairingCode.update({
      where: { id: pairingCode.id },
      data: {
        used: true,
        usedAt: new Date(),
        deviceId: device.id,
      },
    })

    return successResponse({
      paired: true,
      apiKey: device.apiKey,
      device: {
        id: device.id,
        name: device.name,
        deviceType: device.deviceType,
      },
    }, 'Device paired successfully')
  } catch (error) {
    console.error('Auto-pair error:', error)
    return errorResponse('Failed to check pairing status', 500)
  }
}
