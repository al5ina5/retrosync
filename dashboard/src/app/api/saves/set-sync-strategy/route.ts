import { NextRequest } from 'next/server'
import { prisma } from '@/lib/prisma'
import { getUserFromRequest } from '@/lib/auth'
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/utils'
import { canEnableSharedSave } from '@/lib/planLimits'
import { z } from 'zod'

const SYNC_STRATEGIES = ['shared', 'per_device'] as const

const setSyncStrategySchema = z.object({
  saveId: z.string().min(1, 'saveId is required'),
  syncStrategy: z.enum(SYNC_STRATEGIES),
})

/**
 * PATCH /api/saves/set-sync-strategy - Set sync strategy for a Save (per game)
 * Body: { saveId: string, syncStrategy: "shared" | "per_device" }
 * - shared: one version syncs to all devices (latest wins)
 * - per_device: each device has its own version, all backed up, no cross-device sync
 */
export async function PATCH(request: NextRequest) {
  try {
    const user = getUserFromRequest(request)
    if (!user) return unauthorizedResponse()

    const body = await request.json()
    const validation = setSyncStrategySchema.safeParse(body)
    if (!validation.success) {
      return errorResponse(validation.error.errors[0].message, 400)
    }

    const { saveId, syncStrategy } = validation.data

    const save = await prisma.save.findUnique({
      where: { id: saveId },
      select: { id: true, userId: true, saveKey: true, displayName: true },
    })

    if (!save) return errorResponse('Save not found', 404)
    if (save.userId !== user.userId) {
      return unauthorizedResponse('Not authorized to modify this save')
    }

    if (syncStrategy === 'shared') {
      const sharedLimit = await canEnableSharedSave(user.userId, save.id)
      if (!sharedLimit.allowed) {
        return errorResponse(sharedLimit.reason || 'Shared save limit reached', 402)
      }
    }

    await prisma.save.update({
      where: { id: saveId },
      data: { syncStrategy },
    })

    return successResponse({
      save: {
        id: save.id,
        saveKey: save.saveKey,
        displayName: save.displayName,
        syncStrategy,
      },
    })
  } catch (error) {
    console.error('Set sync strategy error:', error)
    return errorResponse('Failed to set sync strategy', 500)
  }
}
