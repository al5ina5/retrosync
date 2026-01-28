import { NextRequest } from 'next/server'
import { prisma } from '@/lib/prisma'
import { successResponse, errorResponse } from '@/lib/utils'
import { z } from 'zod'

const checkPairingSchema = z.object({
  deviceId: z.string().length(6, 'Device ID must be 6 digits'),
})

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()

    // Validate input
    const validation = checkPairingSchema.safeParse(body)
    if (!validation.success) {
      return errorResponse(validation.error.errors[0].message)
    }

    const { deviceId } = validation.data

    // Find pairing code for this device identifier that's not used and not expired
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
      return successResponse({
        hasPairingCode: false,
      }, 'No pairing code found')
    }

    return successResponse({
      hasPairingCode: true,
      code: pairingCode.code,
      userId: pairingCode.userId,
    }, 'Pairing code found')
  } catch (error) {
    console.error('Check pairing error:', error)
    return errorResponse('Failed to check pairing status', 500)
  }
}
