import { NextRequest } from 'next/server'
import { prisma } from '@/lib/prisma'
import { getUserFromRequest } from '@/lib/auth'
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/utils'

/**
 * @deprecated Use PATCH /api/saves/set-sync-mode with syncMode: "sync" | "upload_only" | "disabled"
 * Legacy PATCH /api/saves/toggle-sync - Maps syncEnabled (true -> "sync", false -> "disabled") and updates SaveLocation.
 */
export async function PATCH(request: NextRequest) {
  try {
    const user = getUserFromRequest(request)
    if (!user) return unauthorizedResponse()

    const body = await request.json()
    const saveLocationId = body?.saveLocationId
    const syncEnabled = body?.syncEnabled

    if (!saveLocationId || typeof syncEnabled !== 'boolean') {
      return errorResponse('saveLocationId and syncEnabled are required', 400)
    }

    const syncMode = syncEnabled ? 'sync' : 'disabled'

    const location = await prisma.saveLocation.findUnique({
      where: { id: saveLocationId },
      include: {
        save: { select: { userId: true } },
      },
    })

    if (!location) return errorResponse('Save location not found', 404)
    if (location.save.userId !== user.userId) {
      return unauthorizedResponse('Not authorized to modify this save location')
    }

    const updated = await prisma.saveLocation.update({
      where: { id: saveLocationId },
      data: { syncMode },
      include: {
        device: {
          select: { id: true, name: true, deviceType: true },
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
        syncEnabled: updated.syncMode === 'sync',
        syncMode: updated.syncMode,
      },
    })
  } catch (error) {
    console.error('Toggle sync (legacy) error:', error)
    return errorResponse('Failed to toggle sync', 500)
  }
}
