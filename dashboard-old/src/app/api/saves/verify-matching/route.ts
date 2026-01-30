import { NextRequest } from 'next/server'
import { prisma } from '@/lib/prisma'
import { getUserFromRequest } from '@/lib/auth'
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/utils'

/**
 * GET /api/saves/verify-matching
 * Diagnostic endpoint to verify save matching across devices
 */
export async function GET(request: NextRequest) {
  try {
    const user = getUserFromRequest(request)
    if (!user) {
      return unauthorizedResponse()
    }

    // Get all saves for this user
    const saves = await prisma.save.findMany({
      where: { userId: user.userId },
      include: {
        versions: {
          include: {
            device: {
              select: { id: true, name: true, deviceType: true },
            },
          },
          orderBy: { uploadedAt: 'desc' },
        },
        locations: {
          include: {
            device: {
              select: { id: true, name: true, deviceType: true },
            },
          },
        },
      },
      orderBy: { updatedAt: 'desc' },
    })

    // Analyze matching
    const multiDeviceSaves = saves.filter((s) => s.locations.length > 1)
    const singleDeviceSaves = saves.filter((s) => s.locations.length === 1)

    // Check for potential hash mismatches (same saveKey, different content)
    const hashMismatches: Array<{
      saveKey: string
      saveId: string
      versions: Array<{ device: string; hash: string; size: number; localModifiedAt: Date }>
    }> = []

    saves.forEach((save) => {
      if (save.versions.length > 1) {
        const uniqueHashes = new Set(save.versions.map((v) => v.contentHash))
        if (uniqueHashes.size > 1) {
          hashMismatches.push({
            saveKey: save.saveKey,
            saveId: save.id,
            versions: save.versions.map((v) => ({
              device: v.device.name,
              hash: v.contentHash,
              size: v.byteSize,
              localModifiedAt: v.localModifiedAt,
            })),
          })
        }
      }
    })

    // Check timestamp accuracy
    const versionsWithRealMtime = saves
      .flatMap((s) => s.versions)
      .filter((v) => {
        const localMs = v.localModifiedAt.getTime()
        const uploadMs = v.uploadedAt.getTime()
        return Math.abs(uploadMs - localMs) > 5000 // More than 5 seconds difference
      })

    return successResponse({
      summary: {
        totalSaves: saves.length,
        multiDeviceSaves: multiDeviceSaves.length,
        singleDeviceSaves: singleDeviceSaves.length,
        totalVersions: saves.reduce((sum, s) => sum + s.versions.length, 0),
        versionsWithRealMtime: versionsWithRealMtime.length,
        hashMismatches: hashMismatches.length,
      },
      multiDeviceSaves: multiDeviceSaves.map((save) => ({
        saveKey: save.saveKey,
        displayName: save.displayName,
        saveId: save.id,
        devices: save.locations.map((loc) => ({
          device: loc.device.name,
          deviceType: loc.device.deviceType,
          localPath: loc.localPath,
        })),
        versions: save.versions.map((v) => ({
          device: v.device.name,
          contentHash: v.contentHash.substring(0, 16) + '...',
          byteSize: v.byteSize,
          localModifiedAt: v.localModifiedAt.toISOString(),
          uploadedAt: v.uploadedAt.toISOString(),
          mtimeDiff: v.uploadedAt.getTime() - v.localModifiedAt.getTime(),
        })),
      })),
      hashMismatches: hashMismatches.map((m) => ({
        saveKey: m.saveKey,
        saveId: m.saveId,
        warning: 'Same filename but different content hashes - may be different games',
        versions: m.versions,
      })),
      timestampIssues: {
        totalVersions: saves.reduce((sum, s) => sum + s.versions.length, 0),
        versionsWithRealMtime: versionsWithRealMtime.length,
        versionsUsingUploadTime: saves.reduce((sum, s) => sum + s.versions.length, 0) - versionsWithRealMtime.length,
        message:
          versionsWithRealMtime.length === 0
            ? '⚠️ All versions using upload time - client may not be sending mtime'
            : '✅ Some versions have real mtime',
      },
    })
  } catch (error) {
    console.error('Verify matching error:', error)
    return errorResponse('Failed to verify matching', 500)
  }
}
