import { NextRequest } from 'next/server'
import { prisma } from '@/lib/prisma'
import { getUserFromRequest } from '@/lib/auth'
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/utils'
import { z } from 'zod'

const toggleSyncSchema = z.object({
  saveLocationId: z.string().min(1, 'saveLocationId is required'),
  syncEnabled: z.boolean(),
})

/**
 * PATCH /api/saves/toggle-sync - Toggle syncEnabled for a SaveLocation
 * Body: { saveLocationId: string, syncEnabled: boolean }
 */
export async function PATCH(request: NextRequest) {
  try {
    const user = getUserFromRequest(request)
    if (!user) {
      return unauthorizedResponse()
    }

    const body = await request.json()
    const validation = toggleSyncSchema.safeParse(body)
    if (!validation.success) {
      return errorResponse(validation.error.errors[0].message, 400)
    }

    const { saveLocationId, syncEnabled } = validation.data

    // Verify the SaveLocation belongs to the user
    const location = await prisma.saveLocation.findUnique({
      where: { id: saveLocationId },
      include: {
        save: {
          select: { userId: true },
        },
      },
    })

    if (!location) {
      return errorResponse('Save location not found', 404)
    }

    if (location.save.userId !== user.userId) {
      return unauthorizedResponse('Not authorized to modify this save location')
    }

    // Update syncEnabled
    const updated = await prisma.saveLocation.update({
      where: { id: saveLocationId },
      data: { syncEnabled },
      include: {
        device: {
          select: {
            id: true,
            name: true,
            deviceType: true,
          },
        },
      },
    })

    return successResponse({
      saveLocation: {
        id: updated.id,
        deviceId: updated.deviceId,
        deviceName: updated.device.name,
        deviceType: updated.device.deviceType,
        localPath: updated.localPath,
        syncEnabled: updated.syncEnabled,
      },
    })
  } catch (error) {
    console.error('Toggle sync error:', error)
    return errorResponse('Failed to toggle sync', 500)
  }
}
