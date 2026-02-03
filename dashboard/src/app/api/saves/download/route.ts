import { NextRequest } from 'next/server'
import { prisma } from '@/lib/prisma'
import { getUserFromRequest } from '@/lib/auth'
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/utils'
import { getPresignedUrl } from '@/lib/s3'
import { canDownloadDashboardSave } from '@/lib/planLimits'

export const dynamic = 'force-dynamic'

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

    // filePath from the dashboard is Save.saveKey (same value used in the saves list).
    // Find the Save for this user and get the latest version's storageKey (actual S3 key).
    const save = await prisma.save.findFirst({
      where: {
        userId: user.userId,
        saveKey: filePath,
      },
      select: { id: true, displayName: true },
    })

    if (!save) {
      return errorResponse('Save file not found', 404)
    }

    const downloadLimit = await canDownloadDashboardSave(user.userId)
    if (!downloadLimit.allowed) {
      return errorResponse(downloadLimit.reason || 'Download limit reached', 402)
    }

    // If deviceId is provided, ensure it belongs to the user and get that device's latest version.
    const latestVersion = await prisma.saveVersion.findFirst({
      where: {
        saveId: save.id,
        ...(deviceId
          ? { deviceId, device: { userId: user.userId } }
          : { device: { userId: user.userId } }),
      },
      orderBy: { uploadedAt: 'desc' },
      select: { id: true, storageKey: true },
    })

    if (!latestVersion) {
      return errorResponse('Save file not found', 404)
    }

    const url = getPresignedUrl(
      latestVersion.storageKey,
      60 * 10,
      save.displayName
    )

    await prisma.downloadEvent.create({
      data: {
        userId: user.userId,
        saveId: save.id,
        saveVersionId: latestVersion.id,
      },
    })

    return successResponse({ url })
  } catch (error) {
    console.error('Get download URL error:', error)
    return errorResponse('Failed to generate download URL', 500)
  }
}
