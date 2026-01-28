import { NextRequest } from 'next/server'
import { prisma } from '@/lib/prisma'
import { generateApiKey } from '@/lib/auth'
import { successResponse, errorResponse } from '@/lib/utils'
import { z } from 'zod'

const statusSchema = z.object({
  code: z.string().length(6, 'Code must be 6 characters'),
})

/**
 * POST /api/devices/status
 * Device polls this endpoint to check if code is linked and get API key
 * No authentication required
 */
export async function POST(request: NextRequest) {
  try {
    const body = await request.json()

    // Validate input
    const validation = statusSchema.safeParse(body)
    if (!validation.success) {
      return errorResponse(validation.error.errors[0].message)
    }

    const { code } = validation.data

    // Find pairing code (uppercase for consistency)
    const pairingCode = await prisma.pairingCode.findUnique({
      where: { code: code.toUpperCase() },
      include: {
        user: {
          select: {
            id: true,
            email: true,
          },
        },
      },
    })

    if (!pairingCode) {
      return errorResponse('Code not found', 404)
    }

    // Check if code is expired
    if (new Date() > pairingCode.expiresAt) {
      return errorResponse('Code has expired')
    }

    // If device already exists (already paired)
    if (pairingCode.deviceId) {
      const device = await prisma.device.findUnique({
        where: { id: pairingCode.deviceId },
      })

      if (device) {
        return successResponse({
          status: 'paired',
          apiKey: device.apiKey,
          userId: device.userId,
          device: {
            id: device.id,
            name: device.name,
            deviceType: device.deviceType,
          },
        }, 'Device already paired')
      }
    }

    // If code is linked to user but device not created yet
    if (pairingCode.userId && !pairingCode.used) {
      // Auto-create device and mark code as used
      const apiKey = generateApiKey()
      const deviceName = `${pairingCode.deviceType || 'Device'} ${new Date().toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })}`

      const device = await prisma.device.create({
        data: {
          userId: pairingCode.userId,
          name: deviceName,
          deviceType: pairingCode.deviceType || 'other',
          apiKey,
          lastSyncAt: new Date(),
        },
      })

      // Mark pairing code as used and link to device
      await prisma.pairingCode.update({
        where: { id: pairingCode.id },
        data: {
          used: true,
          usedAt: new Date(),
          deviceId: device.id,
        },
      })

      return successResponse({
        status: 'paired',
        apiKey: device.apiKey,
        userId: device.userId,
        device: {
          id: device.id,
          name: device.name,
          deviceType: device.deviceType,
        },
      }, 'Device paired successfully')
    }

    // Code exists but not linked to user yet
    return successResponse({
      status: 'waiting',
      message: 'Waiting for user to enter code on dashboard',
    }, 'Code not yet linked')
  } catch (error) {
    console.error('Status check error:', error)
    return errorResponse('Failed to check status', 500)
  }
}
