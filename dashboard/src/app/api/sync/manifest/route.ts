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

    // Get saves that this device knows about (has SaveLocation)
    const locations = await prisma.saveLocation.findMany({
      where: {
        deviceId: device.id,
        syncEnabled: true, // Only include saves where sync is enabled
      },
      include: {
        save: {
          include: {
            versions: {
              // Get all versions, we'll sort in code to prefer real mtimes
              orderBy: [{ uploadedAt: 'desc' }],
            },
          },
        },
      },
      orderBy: { updatedAt: 'desc' },
    })

    // MVP: Also include saves from other devices that this device doesn't know about yet
    // This allows the client to show "Run game once to enable syncing" messages
    const allUserSaves = await prisma.save.findMany({
      where: {
        userId: device.userId,
      },
      include: {
        versions: {
          orderBy: [{ uploadedAt: 'desc' }],
        },
        locations: {
          where: {
            deviceId: device.id,
          },
        },
      },
    })

    // Find saves that don't have a SaveLocation for this device
    const unmappedSaves = allUserSaves.filter(
      (save) => save.locations.length === 0
    )

    // If a device has multiple locations for the same save (e.g., different cores),
    // pick the one with the latest version. Group by saveId first.
    const locationsBySave = new Map<string, typeof locations>()
    for (const loc of locations) {
      const existing = locationsBySave.get(loc.saveId)
      if (!existing) {
        locationsBySave.set(loc.saveId, [loc])
      } else {
        existing.push(loc)
      }
    }

    // For each save, if multiple locations exist, pick the one with the latest version
    const selectedLocations: typeof locations = []
    locationsBySave.forEach((locs, saveId) => {
      if (locs.length === 1) {
        selectedLocations.push(locs[0])
      } else {
        // Multiple locations for same save - find the one with latest version
        let latestLoc = locs[0]
        let latestTime = 0

        for (const loc of locs) {
          // Get the latest version for this location's save
          const versions = loc.save.versions
          if (versions.length > 0) {
            const latest = versions[0]
            const versionTime = latest.localModifiedAt.getTime()
            if (versionTime > latestTime) {
              latestTime = versionTime
              latestLoc = loc
            }
          }
        }

        selectedLocations.push(latestLoc)
        console.log(
          `[Manifest] Device ${device.id} has ${locs.length} locations for save ${latestLoc.save.saveKey}, selected latest: ${latestLoc.localPath}`
        )
      }
    })

    const manifest = selectedLocations.map((loc) => {
      // Select latest version, preferring real mtimes over fallback times
      // BUT: if newest fallback time is significantly newer than newest real mtime,
      // prefer the fallback (prevents broken clocks from overwriting newer files)
      const SAFETY_THRESHOLD_MS = 7 * 24 * 60 * 60 * 1000 // 7 days

      const versions = loc.save.versions.map((v) => {
        const localMs = v.localModifiedAt.getTime()
        const uploadMs = v.uploadedAt.getTime()
        const diff = Math.abs(uploadMs - localMs)
        const hasRealMtime = diff > 5000 // More than 5 seconds difference = real mtime
        return {
          version: v,
          hasRealMtime,
          localModifiedAt: v.localModifiedAt,
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

      const latest = versions[0]?.version

      return {
        saveId: loc.saveId,
        saveKey: loc.save.saveKey,
        displayName: loc.save.displayName,
        localPath: loc.localPath,
        deviceType: loc.deviceType,
        needsMapping: false, // This device knows where to save this file
        latestVersion: latest
          ? {
            id: latest.id,
            contentHash: latest.contentHash,
            byteSize: latest.byteSize,
            localModifiedAt: latest.localModifiedAt,
            localModifiedAtMs: latest.localModifiedAt.getTime(),
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
        const localMs = v.localModifiedAt.getTime()
        const uploadMs = v.uploadedAt.getTime()
        const diff = Math.abs(uploadMs - localMs)
        const hasRealMtime = diff > 5000
        return {
          version: v,
          hasRealMtime,
          localModifiedAt: v.localModifiedAt,
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

      const latest = versions[0]?.version

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
            localModifiedAt: latest.localModifiedAt,
            localModifiedAtMs: latest.localModifiedAt.getTime(),
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

