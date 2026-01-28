import { NextRequest } from 'next/server'
import { prisma } from '@/lib/prisma'
import { getUserFromRequest, extractApiKey } from '@/lib/auth'
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/utils'
import { deleteFile } from '@/lib/s3'

/**
 * GET /api/saves - List all saves for the authenticated user
 * Supports both JWT token (web dashboard) and API key (client devices)
 */
export async function GET(request: NextRequest) {
  try {
    let userId: string | null = null

    // Try API key authentication first (for client devices)
    const apiKey = extractApiKey(request)
    if (apiKey) {
      const device = await prisma.device.findUnique({
        where: { apiKey },
        select: { userId: true },
      })

      if (!device) {
        return unauthorizedResponse('Invalid API key')
      }

      userId = device.userId
    } else {
      // Fall back to JWT token authentication (for web dashboard)
      const user = getUserFromRequest(request)
      if (!user) {
        return unauthorizedResponse()
      }
      userId = user.userId
    }

    if (!userId) {
      return unauthorizedResponse()
    }

    // Get all saves for this user with their locations
    const saves = await prisma.save.findMany({
      where: { userId },
      include: {
        locations: {
          include: {
            device: {
              select: {
                id: true,
                name: true,
                deviceType: true,
              },
            },
          },
        },
        // IMPORTANT: we intentionally fetch **all** versions here (no `take: 1`)
        // so we can build accurate per-device "latest modified/uploaded" timestamps
        // for the dashboard. We still treat versions[0] as the globally-latest
        // by ordering descending below.
        versions: {
          orderBy: [{ localModifiedAt: 'desc' }, { uploadedAt: 'desc' }],
          include: {
            device: {
              select: {
                id: true,
                name: true,
                deviceType: true,
              },
            },
          },
        },
      },
      orderBy: { updatedAt: 'desc' },
    })

    // Format saves for the UI
    const formattedSaves = saves.map((save) => {
      const latestVersion = save.versions[0]
      const latestDeviceId = latestVersion?.device?.id || null
      const latestLocalModifiedAt = latestVersion?.localModifiedAt || null

      // Build a per-device view of latest version timestamps so we can
      // show both modified and uploaded times for each location in the UI.
      const latestByDevice = new Map<
        string,
        {
          modifiedAt: Date
          uploadedAt: Date
        }
      >()

      for (const version of save.versions) {
        const existing = latestByDevice.get(version.deviceId)
        const candidateModifiedAt = version.localModifiedAt || version.uploadedAt

        if (!candidateModifiedAt) continue

        if (!existing || candidateModifiedAt.getTime() > existing.modifiedAt.getTime()) {
          latestByDevice.set(version.deviceId, {
            modifiedAt: candidateModifiedAt,
            uploadedAt: version.uploadedAt || candidateModifiedAt,
          })
        }
      }

      return {
        id: save.id,
        saveKey: save.saveKey,
        displayName: save.displayName,
        fileSize: latestVersion?.byteSize || 0,
        lastModifiedAt: latestVersion?.localModifiedAt || save.updatedAt,
        uploadedAt: latestVersion?.uploadedAt || save.updatedAt,
        locations: save.locations.map((loc) => {
          const latestForDevice = latestByDevice.get(loc.deviceId) || null

          return {
            id: loc.id,
            deviceId: loc.deviceId,
            deviceName: loc.device.name,
            deviceType: loc.device.deviceType,
            localPath: loc.localPath,
            syncEnabled: loc.syncEnabled,
            isLatest: loc.deviceId === latestDeviceId,
            latestModifiedAt: loc.deviceId === latestDeviceId ? latestLocalModifiedAt : null,
            modifiedAt: latestForDevice?.modifiedAt || null,
            uploadedAt: latestForDevice?.uploadedAt || null,
          }
        }),
        latestVersionDevice: latestVersion?.device
          ? {
            id: latestVersion.device.id,
            name: latestVersion.device.name,
            deviceType: latestVersion.device.deviceType,
          }
          : null,
      }
    })

    // Sort by real mtime (lastModifiedAt) descending - most recently modified first
    formattedSaves.sort((a, b) => {
      const timeA = new Date(a.lastModifiedAt).getTime()
      const timeB = new Date(b.lastModifiedAt).getTime()
      return timeB - timeA
    })

    return successResponse({
      saves: formattedSaves,
      count: formattedSaves.length,
    })
  } catch (error) {
    console.error('List saves error:', error)
    return errorResponse('Failed to list saves', 500)
  }
}

/**
 * DELETE /api/saves - Delete a save file
 */
export async function DELETE(request: NextRequest) {
  try {
    // Authenticate user
    const user = getUserFromRequest(request)
    if (!user) {
      return unauthorizedResponse()
    }

    // Get filePath from query parameters
    const { searchParams } = new URL(request.url)
    const filePath = searchParams.get('filePath')

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

    // Find all sync logs for this filePath from user's devices
    const syncLogs = await prisma.syncLog.findMany({
      where: {
        deviceId: { in: deviceIds },
        filePath: filePath,
      },
      include: {
        device: {
          select: {
            id: true,
          },
        },
      },
    })

    if (syncLogs.length === 0) {
      return errorResponse('Save file not found', 404)
    }

    // Delete files from S3
    const deletePromises: Promise<void>[] = []
    for (const log of syncLogs) {
      // Construct S3 key: userId/deviceId/filePath
      // Normalize and strictly validate path segments to avoid traversal.
      const sanitizedPath = filePath.replace(/^\//, '')
      if (sanitizedPath.includes('..')) {
        return errorResponse('Invalid file path', 400)
      }
      const s3Key = `${user.userId}/${log.device.id}/${sanitizedPath}`

      // Attempt to delete from S3 (don't fail if file doesn't exist)
      deletePromises.push(
        deleteFile(s3Key).catch((error) => {
          console.warn(`Failed to delete S3 file ${s3Key}:`, error)
          // Continue even if S3 delete fails
        })
      )
    }

    await Promise.all(deletePromises)

    // Delete sync logs
    await prisma.syncLog.deleteMany({
      where: {
        id: { in: syncLogs.map((log) => log.id) },
      },
    })

    return successResponse({
      message: 'Save file deleted successfully',
      deletedCount: syncLogs.length,
    })
  } catch (error) {
    console.error('Delete save error:', error)
    return errorResponse('Failed to delete save', 500)
  }
}
