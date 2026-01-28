import { NextRequest } from 'next/server'
import { prisma } from '@/lib/prisma'
import { getUserFromRequest } from '@/lib/auth'
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/utils'

/**
 * GET /api/saves - List all saves for the authenticated user
 */
export async function GET(request: NextRequest) {
  try {
    // Authenticate user
    const user = getUserFromRequest(request)
    if (!user) {
      return unauthorizedResponse()
    }

    // Get all devices for this user
    const devices = await prisma.device.findMany({
      where: { userId: user.userId },
      select: { id: true },
    })

    const deviceIds = devices.map((d) => d.id)

    if (deviceIds.length === 0) {
      return successResponse({
        saves: [],
        count: 0,
      })
    }

    // Get all sync logs for user's devices, ordered by most recent
    const syncLogs = await prisma.syncLog.findMany({
      where: {
        deviceId: { in: deviceIds },
        action: 'upload',
        status: 'success',
      },
      include: {
        device: {
          select: {
            id: true,
            name: true,
            deviceType: true,
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
      take: 100, // Limit to most recent 100 uploads
    })

    // Group by file path and get the most recent upload for each file
    const fileMap = new Map<string, typeof syncLogs[0]>()
    for (const log of syncLogs) {
      const existing = fileMap.get(log.filePath)
      if (!existing || new Date(log.createdAt) > new Date(existing.createdAt)) {
        fileMap.set(log.filePath, log)
      }
    }

    // Convert to array and format
    const saves = Array.from(fileMap.values()).map((log) => ({
      filePath: log.filePath,
      fileName: log.filePath.split('/').pop() || log.filePath,
      fileSize: log.fileSize || 0,
      uploadedAt: log.createdAt,
      device: {
        id: log.device.id,
        name: log.device.name,
        deviceType: log.device.deviceType,
      },
    }))

    return successResponse({
      saves,
      count: saves.length,
    })
  } catch (error) {
    console.error('List saves error:', error)
    return errorResponse('Failed to list saves', 500)
  }
}
