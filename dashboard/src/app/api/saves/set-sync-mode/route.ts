import { NextRequest } from 'next/server'
import { prisma } from '@/lib/prisma'
import { getUserFromRequest } from '@/lib/auth'
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/utils'
import { z } from 'zod'

const SYNC_MODES = ['sync', 'upload_only', 'disabled'] as const

const setSyncModeSchema = z.object({
  saveLocationId: z.string().min(1, 'saveLocationId is required'),
  syncMode: z.enum(SYNC_MODES),
})

/**
 * PATCH /api/saves/set-sync-mode - Set sync mode for a SaveLocation
 * Body: { saveLocationId: string, syncMode: "sync" | "upload_only" | "disabled" }
 */
export async function PATCH(request: NextRequest) {
  try {
    const user = getUserFromRequest(request)
    if (!user) {
      return unauthorizedResponse()
    }

    const body = await request.json()
    const validation = setSyncModeSchema.safeParse(body)
    if (!validation.success) {
      return errorResponse(validation.error.errors[0].message, 400)
    }

    const { saveLocationId, syncMode } = validation.data

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

    const updated = await prisma.saveLocation.update({
      where: { id: saveLocationId },
      data: { syncMode },
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
        syncMode: updated.syncMode,
      },
    })
  } catch (error) {
    console.error('Set sync mode error:', error)
    return errorResponse('Failed to set sync mode', 500)
  }
}
