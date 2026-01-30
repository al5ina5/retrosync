import { NextRequest } from 'next/server'
import { prisma } from '@/lib/prisma'
import { extractApiKey } from '@/lib/auth'
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/utils'

/**
 * GET /api/sync/manifest
 * Returns, for the authenticated device, the list of saves it knows about
 * (SaveLocation mappings) plus the latest cloud version for each save.
 */
export async function GET(request: NextRequest) {
  try {
    const apiKey = extractApiKey(request)
    if (!apiKey) return unauthorizedResponse('API key is required')

    const device = await prisma.device.findUnique({
      where: { apiKey },
      include: { user: true },
    })
    if (!device) return unauthorizedResponse('Invalid API key')

    // Sanity check: timestamps should be reasonable (between 2020 and 1 year in the future)
    // Some devices sent CRC values as timestamps due to stat failures, causing invalid dates
    const MIN_VALID_TIMESTAMP = new Date('2020-01-01').getTime()
    const MAX_VALID_TIMESTAMP = Date.now() + 365 * 24 * 60 * 60 * 1000 // 1 year from now

    const sanitizeTimestamp = (date: Date | null, fallback: Date): Date => {
      if (!date) return fallback
      const time = date.getTime()
      if (time < MIN_VALID_TIMESTAMP || time > MAX_VALID_TIMESTAMP) {
        // Timestamp is invalid (likely a CRC value), use fallback
        return fallback
      }
      return date
    }

    // Get saves that this device knows about (has SaveLocation)
    // Only "shared" saves are in the manifest (one version syncs to all); "per_device" = each device has its own, no download
    const locationsRaw = await prisma.saveLocation.findMany({
      where: { deviceId: device.id },
      include: {
        save: {
          include: {
            versions: {
              orderBy: [{ uploadedAt: 'desc' }],
            },
          },
        },
      },
      orderBy: { updatedAt: 'desc' },
    })
    const locations = locationsRaw.filter((loc) => loc.save.syncStrategy === 'shared')

    // Include unmapped saves (from other devices) so client can show "Run game once to enable syncing"
    // Only include unmapped saves that are shared (per_device saves aren't offered for download)
    const allUserSaves = await prisma.save.findMany({
      where: { userId: device.userId },
      include: {
        versions: { orderBy: [{ uploadedAt: 'desc' }] },
        locations: { where: { deviceId: device.id } },
      },
    })
    const unmappedSaves = allUserSaves.filter(
      (save) => save.locations.length === 0 && save.syncStrategy === 'shared'
    )

    // Include ALL locations for each save (different emulator folders should all be tracked)
    // The client needs to know about all paths to avoid re-uploading the same content
    // from different folders (e.g., gpSP vs mGBA, LudicrousN64 vs Mupen64Plus-Next)
    const selectedLocations = locations

    const manifest = selectedLocations.map((loc) => {
      // Select latest version, preferring real mtimes over fallback times
      // BUT: if newest fallback time is significantly newer than newest real mtime,
      // prefer the fallback (prevents broken clocks from overwriting newer files)
      const SAFETY_THRESHOLD_MS = 7 * 24 * 60 * 60 * 1000 // 7 days

      const versions = loc.save.versions.map((v) => {
        // Sanitize timestamps - use uploadedAt as fallback for corrupted localModifiedAt
        const sanitizedLocalModifiedAt = sanitizeTimestamp(v.localModifiedAt, v.uploadedAt)
        const localMs = sanitizedLocalModifiedAt.getTime()
        const uploadMs = v.uploadedAt.getTime()
        const diff = Math.abs(uploadMs - localMs)
        const hasRealMtime = diff > 5000 // More than 5 seconds difference = real mtime
        return {
          version: v,
          hasRealMtime,
          localModifiedAt: sanitizedLocalModifiedAt,
          uploadedAt: v.uploadedAt,
          localMs,
          uploadMs,
        }
      })

      // Find newest real mtime and newest fallback time
      let newestRealMtime: typeof versions[0] | null = null
      let newestFallbackTime: typeof versions[0] | null = null

      for (const v of versions) {
        if (v.hasRealMtime) {
          if (!newestRealMtime || v.localMs > newestRealMtime.localMs) {
            newestRealMtime = v
          }
        } else {
          if (!newestFallbackTime || v.uploadMs > newestFallbackTime.uploadMs) {
            newestFallbackTime = v
          }
        }
      }

      // Safety check: if fallback is significantly newer, prefer it over broken real mtime
      let preferFallback = false
      if (newestRealMtime && newestFallbackTime) {
        const realMtimeMs = newestRealMtime.localMs
        const fallbackMs = newestFallbackTime.uploadMs
        const daysDiff = (fallbackMs - realMtimeMs) / (24 * 60 * 60 * 1000)
        if (daysDiff > 7) {
          preferFallback = true
          console.log(
            `[Manifest] Safety: Preferring fallback over real mtime (${daysDiff.toFixed(1)} days newer) for save ${loc.save.saveKey}`
          )
        }
      }

      // Sort: if preferFallback, put fallbacks first; otherwise prefer real mtimes
      versions.sort((a, b) => {
        if (preferFallback) {
          // When preferring fallback, sort by uploadedAt DESC (fallbacks use upload time)
          if (a.hasRealMtime !== b.hasRealMtime) {
            return a.hasRealMtime ? 1 : -1 // Fallback comes first
          }
          // Both same type, sort by appropriate time
          if (a.hasRealMtime) {
            return b.localMs - a.localMs // Real mtimes: by localModifiedAt DESC
          } else {
            return b.uploadMs - a.uploadMs // Fallbacks: by uploadedAt DESC
          }
        } else {
          // Normal: prefer real mtimes
          if (a.hasRealMtime !== b.hasRealMtime) {
            return a.hasRealMtime ? -1 : 1 // Real mtime comes first
          }
          const aTime = a.localModifiedAt.getTime()
          const bTime = b.localModifiedAt.getTime()
          if (aTime !== bTime) {
            return bTime - aTime // Descending
          }
          return b.uploadedAt.getTime() - a.uploadedAt.getTime() // Descending
        }
      })

      const latestWrapper = versions[0]
      const latest = latestWrapper?.version

      return {
        saveId: loc.saveId,
        saveKey: loc.save.saveKey,
        displayName: loc.save.displayName,
        // Each device has its own localPath (e.g. .sav on macOS, .srm on MUOS/RetroArch); download uses this path.
        localPath: loc.localPath,
        deviceType: loc.deviceType,
        needsMapping: false, // This device knows where to save this file
        latestVersion: latest
          ? {
            id: latest.id,
            contentHash: latest.contentHash,
            byteSize: latest.byteSize,
            // Use sanitized timestamp from wrapper
            localModifiedAt: latestWrapper.localModifiedAt,
            localModifiedAtMs: latestWrapper.localMs,
            uploadedAt: latest.uploadedAt,
            uploadedAtMs: latest.uploadedAt.getTime(),
          }
          : null,
      }
    })

    // Add unmapped saves (from other devices) to manifest
    // These will be shown to the user with a message to run the game once
    const unmappedManifest = unmappedSaves.map((save) => {
      // Get latest version for this save
      const versions = save.versions.map((v) => {
        // Sanitize timestamps - use uploadedAt as fallback for corrupted localModifiedAt
        const sanitizedLocalModifiedAt = sanitizeTimestamp(v.localModifiedAt, v.uploadedAt)
        const localMs = sanitizedLocalModifiedAt.getTime()
        const uploadMs = v.uploadedAt.getTime()
        const diff = Math.abs(uploadMs - localMs)
        const hasRealMtime = diff > 5000
        return {
          version: v,
          hasRealMtime,
          localModifiedAt: sanitizedLocalModifiedAt,
          uploadedAt: v.uploadedAt,
          localMs,
          uploadMs,
        }
      })

      versions.sort((a, b) => {
        if (a.hasRealMtime !== b.hasRealMtime) {
          return a.hasRealMtime ? -1 : 1
        }
        const aTime = a.localModifiedAt.getTime()
        const bTime = b.localModifiedAt.getTime()
        if (aTime !== bTime) {
          return bTime - aTime
        }
        return b.uploadedAt.getTime() - a.uploadedAt.getTime()
      })

      const latestWrapper = versions[0]
      const latest = latestWrapper?.version

      return {
        saveId: save.id,
        saveKey: save.saveKey,
        displayName: save.displayName,
        localPath: null, // No path yet - device needs to upload first
        deviceType: device.deviceType,
        needsMapping: true, // Device needs to run game once to enable syncing
        latestVersion: latest
          ? {
            id: latest.id,
            contentHash: latest.contentHash,
            byteSize: latest.byteSize,
            // Use sanitized timestamp from wrapper
            localModifiedAt: latestWrapper.localModifiedAt,
            localModifiedAtMs: latestWrapper.localMs,
            uploadedAt: latest.uploadedAt,
            uploadedAtMs: latest.uploadedAt.getTime(),
          }
          : null,
      }
    })

    // Combine mapped and unmapped saves
    const fullManifest = [...manifest, ...unmappedManifest]

    return successResponse({
      device: { id: device.id, deviceType: device.deviceType },
      manifest: fullManifest,
      count: fullManifest.length,
      mappedCount: manifest.length,
      unmappedCount: unmappedManifest.length,
    })
  } catch (err) {
    console.error('Manifest error:', err)
    return errorResponse('Failed to build manifest', 500)
  }
}

