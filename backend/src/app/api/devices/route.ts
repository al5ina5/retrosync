import { NextRequest } from 'next/server'
import { prisma } from '@/lib/prisma'
import { getUserFromRequest, extractApiKey } from '@/lib/auth'
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/utils'

/**
 * GET /api/devices - List user's devices
 */
export async function GET(request: NextRequest) {
  try {
    // Authenticate user
    const user = getUserFromRequest(request)
    if (!user) {
      return unauthorizedResponse()
    }

    // Fetch user's devices
    const devices = await prisma.device.findMany({
      where: {
        userId: user.userId,
      },
      select: {
        id: true,
        name: true,
        deviceType: true,
        lastSyncAt: true,
        isActive: true,
        createdAt: true,
        updatedAt: true,
      },
      orderBy: {
        createdAt: 'desc',
      },
    })

    return successResponse({ devices })
  } catch (error) {
    console.error('Fetch devices error:', error)
    return errorResponse('Failed to fetch devices', 500)
  }
}

/**
 * DELETE /api/devices - Delete a device
 */
export async function DELETE(request: NextRequest) {
  try {
    // Authenticate user
    const user = getUserFromRequest(request)
    if (!user) {
      return unauthorizedResponse()
    }

    const { searchParams } = new URL(request.url)
    const deviceId = searchParams.get('id')

    if (!deviceId) {
      return errorResponse('Device ID is required')
    }

    // Check if device belongs to user
    const device = await prisma.device.findFirst({
      where: {
        id: deviceId,
        userId: user.userId,
      },
    })

    if (!device) {
      return errorResponse('Device not found', 404)
    }

    // Delete device
    await prisma.device.delete({
      where: { id: deviceId },
    })

    return successResponse({ message: 'Device deleted successfully' })
  } catch (error) {
    console.error('Delete device error:', error)
    return errorResponse('Failed to delete device', 500)
  }
}
