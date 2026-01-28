import { NextRequest } from 'next/server'
import { prisma } from '@/lib/prisma'
import { extractApiKey } from '@/lib/auth'
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/utils'

/**
 * POST /api/sync/heartbeat - Device check-in
 */
export async function POST(request: NextRequest) {
  try {
    // Authenticate device via API key
    const apiKey = extractApiKey(request)
    if (!apiKey) {
      return unauthorizedResponse('API key is required')
    }

    // Find device
    const device = await prisma.device.findUnique({
      where: { apiKey },
    })

    if (!device) {
      return unauthorizedResponse('Invalid API key')
    }

    // Update last sync time
    await prisma.device.update({
      where: { id: device.id },
      data: {
        lastSyncAt: new Date(),
        isActive: true,
      },
    })

    return successResponse({
      deviceId: device.id,
      deviceName: device.name,
      lastSyncAt: new Date(),
    }, 'Heartbeat received')
  } catch (error) {
    console.error('Heartbeat error:', error)
    return errorResponse('Failed to process heartbeat', 500)
  }
}
