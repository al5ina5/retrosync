import { NextRequest } from 'next/server'
import { prisma } from '@/lib/prisma'
import { extractApiKey, getUserFromRequest } from '@/lib/auth'
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/utils'
import { z } from 'zod'

const syncLogSchema = z.object({
  action: z.enum(['upload', 'download', 'delete', 'conflict']),
  filePath: z.string().min(1),
  fileSize: z.number().optional(),
  status: z.enum(['success', 'failed', 'pending']),
  errorMsg: z.string().optional(),
  metadata: z.string().optional(),
})

/**
 * POST /api/sync/log - Record sync event
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

    const body = await request.json()

    // Validate input
    const validation = syncLogSchema.safeParse(body)
    if (!validation.success) {
      return errorResponse(validation.error.errors[0].message)
    }

    const { action, filePath, fileSize, status, errorMsg, metadata } = validation.data

    // Create sync log
    const syncLog = await prisma.syncLog.create({
      data: {
        deviceId: device.id,
        action,
        filePath,
        fileSize: fileSize || null,
        status,
        errorMsg: errorMsg || null,
        metadata: metadata || null,
      },
    })

    return successResponse({
      logId: syncLog.id,
      createdAt: syncLog.createdAt,
    }, 'Sync event logged successfully')
  } catch (error) {
    console.error('Sync log error:', error)
    return errorResponse('Failed to log sync event', 500)
  }
}

/**
 * GET /api/sync/log - Get sync logs for user's devices
 */
export async function GET(request: NextRequest) {
  try {
    // Authenticate user
    const user = getUserFromRequest(request)
    if (!user) {
      return unauthorizedResponse()
    }

    // Get query parameters
    const { searchParams } = new URL(request.url)
    const deviceId = searchParams.get('deviceId')
    const limit = parseInt(searchParams.get('limit') || '50')
    const offset = parseInt(searchParams.get('offset') || '0')

    // Build query
    const where: any = {}

    if (deviceId) {
      // Verify device belongs to user
      const device = await prisma.device.findFirst({
        where: {
          id: deviceId,
          userId: user.userId,
        },
      })

      if (!device) {
        return errorResponse('Device not found', 404)
      }

      where.deviceId = deviceId
    } else {
      // Get all devices for this user
      const userDevices = await prisma.device.findMany({
        where: { userId: user.userId },
        select: { id: true },
      })

      where.deviceId = {
        in: userDevices.map((d) => d.id),
      }
    }

    // Fetch sync logs
    const [logs, total] = await Promise.all([
      prisma.syncLog.findMany({
        where,
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
        take: limit,
        skip: offset,
      }),
      prisma.syncLog.count({ where }),
    ])

    return successResponse({
      logs,
      total,
      limit,
      offset,
    })
  } catch (error) {
    console.error('Fetch sync logs error:', error)
    return errorResponse('Failed to fetch sync logs', 500)
  }
}
