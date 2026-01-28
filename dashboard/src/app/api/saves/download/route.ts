import { NextRequest } from 'next/server'
import { prisma } from '@/lib/prisma'
import { getUserFromRequest } from '@/lib/auth'
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/utils'
import { getPresignedUrl } from '@/lib/s3'

export async function GET(request: NextRequest) {
  try {
    const user = getUserFromRequest(request)
    if (!user) {
      return unauthorizedResponse()
    }

    const { searchParams } = new URL(request.url)
    const filePath = searchParams.get('filePath')
    const deviceId = searchParams.get('deviceId')

    if (!filePath) {
      return errorResponse('filePath query parameter is required', 400)
    }

    // Get all devices for this user
    const devices = await prisma.device.findMany({
      where: { userId: user.userId },
      select: { id: true },
    })

    const deviceIds = devices.map((d) => d.id)
    if (deviceIds.length === 0) {
      return errorResponse('No devices found for user', 404)
    }

    // If a specific deviceId is provided, ensure it belongs to the user.
    if (deviceId && !deviceIds.includes(deviceId)) {
      return unauthorizedResponse('Device does not belong to user')
    }

    // Find the most recent successful upload for this filePath.
    // If deviceId is provided, limit to that device; otherwise, search across all.
    const latest = await prisma.syncLog.findFirst({
      where: {
        deviceId: deviceId ? deviceId : { in: deviceIds },
        filePath,
        action: 'upload',
        status: 'success',
      },
      orderBy: { createdAt: 'desc' },
      select: { deviceId: true },
    })

    if (!latest) {
      return errorResponse('Save file not found', 404)
    }

    // Construct S3 key: userId/deviceId/filePath
    const sanitizedPath = filePath.replace(/^\//, '')
    if (sanitizedPath.includes('..')) {
      return errorResponse('Invalid file path', 400)
    }
    const s3Key = `${user.userId}/${latest.deviceId}/${sanitizedPath}`

    const url = getPresignedUrl(s3Key, 60 * 10) // 10 minutes

    return successResponse({ url })
  } catch (error) {
    console.error('Get download URL error:', error)
    return errorResponse('Failed to generate download URL', 500)
  }
}

