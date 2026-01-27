import { NextRequest } from 'next/server'
import { prisma } from '@/lib/prisma'
import { generateApiKey } from '@/lib/auth'
import { successResponse, errorResponse } from '@/lib/utils'
import { z } from 'zod'

const pairSchema = z.object({
  code: z.string().length(6, 'Code must be 6 digits'),
  deviceName: z.string().min(1, 'Device name is required'),
  deviceType: z.enum(['rg35xx', 'miyoo_flip', 'windows', 'mac', 'linux', 'other']),
})

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()

    // Validate input
    const validation = pairSchema.safeParse(body)
    if (!validation.success) {
      return errorResponse(validation.error.errors[0].message)
    }

    const { code, deviceName, deviceType } = validation.data

    // Find pairing code
    const pairingCode = await prisma.pairingCode.findUnique({
      where: { code },
    })

    if (!pairingCode) {
      return errorResponse('Invalid pairing code', 404)
    }

    // Check if code is already used
    if (pairingCode.used) {
      return errorResponse('Pairing code has already been used')
    }

    // Check if code is expired
    if (new Date() > pairingCode.expiresAt) {
      return errorResponse('Pairing code has expired')
    }

    // Generate API key
    const apiKey = generateApiKey()

    // Create device
    const device = await prisma.device.create({
      data: {
        userId: pairingCode.userId,
        name: deviceName,
        deviceType,
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

    // Return device credentials
    return successResponse({
      device: {
        id: device.id,
        name: device.name,
        deviceType: device.deviceType,
      },
      userId: pairingCode.userId,
      apiKey: device.apiKey,
      s3Config: {
        endpoint: process.env.MINIO_ENDPOINT || 'http://localhost:9000',
        accessKeyId: process.env.MINIO_ROOT_USER || 'minioadmin',
        secretAccessKey: process.env.MINIO_ROOT_PASSWORD || 'minioadmin',
        bucket: process.env.MINIO_BUCKET || 'retrosync-saves',
      },
    }, 'Device paired successfully')
  } catch (error) {
    console.error('Pairing error:', error)
    return errorResponse('Failed to pair device', 500)
  }
}
