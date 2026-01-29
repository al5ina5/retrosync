import { NextRequest } from 'next/server'
import { prisma } from '@/lib/prisma'
import { extractApiKey } from '@/lib/auth'
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/utils'
import { listFiles, uploadFile } from '@/lib/s3'
import crypto from 'crypto'

/**
 * GET /api/sync/files - List available save files
 */
export async function GET(request: NextRequest) {
  try {
    // Authenticate device via API key
    const apiKey = extractApiKey(request)
    if (!apiKey) {
      return unauthorizedResponse('API key is required')
    }

    // Find device
    const device = await prisma.device.findUnique({
      where: { apiKey },
      include: {
        user: true,
      },
    })

    if (!device) {
      return unauthorizedResponse('Invalid API key')
    }

    // Get query parameters
    const { searchParams } = new URL(request.url)
    const emulatorTypeRaw = searchParams.get('emulator')
    const gameIdRaw = searchParams.get('game')

    // Light validation on prefix components to avoid odd characters affecting S3 queries.
    const safeSegment = (value: string | null): string | null => {
      if (!value) return null
      // Allow common path-safe characters; strip anything else.
      const cleaned = value.replace(/[^a-zA-Z0-9/_\-.]/g, '')
      return cleaned.length > 0 ? cleaned : null
    }

    const emulatorType = safeSegment(emulatorTypeRaw)
    const gameId = safeSegment(gameIdRaw)

    // Build S3 prefix based on filters
    let prefix = `${device.userId}/`

    if (emulatorType && gameId) {
      // List files for specific game
      prefix += `*/${emulatorType}/${gameId}/`
    } else if (emulatorType) {
      // List files for specific emulator
      prefix += `*/${emulatorType}/`
    }
    // Otherwise list all files for user

    // List files from S3
    const s3Files = await listFiles(prefix)

    // Transform S3 files into response format
    const files = s3Files.map((file) => ({
      key: file.Key,
      size: file.Size,
      lastModified: file.LastModified,
    }))

    return successResponse({
      files,
      count: files.length,
    })
  } catch (error) {
    console.error('List files error:', error)
    return errorResponse('Failed to list files', 500)
  }
}

/**
 * POST /api/sync/files - Upload file content and metadata to S3
 */
export async function POST(request: NextRequest) {
  try {
    // Authenticate device via API key
    const apiKey = extractApiKey(request)
    if (!apiKey) {
      return unauthorizedResponse('API key is required')
    }

    // Find device with user info
    const device = await prisma.device.findUnique({
      where: { apiKey },
      include: {
        user: true,
      },
    })

    if (!device) {
      return unauthorizedResponse('Invalid API key')
    }

    const body = await request.json()
    const { filePath, fileSize, action, fileContent } = body as {
      filePath?: string
      fileSize?: number
      action?: string
      fileContent?: string
      // New (optional) fields for download-sync
      localPath?: string
      localModifiedAt?: string | number // ISO string or epoch ms
      saveKey?: string
      contentHash?: string // sha256 hex
    }

    if (!filePath || !action) {
      return errorResponse('filePath and action are required')
    }

    let s3Key: string | null = null
    let uploadSuccess = false

    // If fileContent is provided, upload to S3 and create Save/Version/Location metadata
    if (fileContent && action === 'upload') {
      try {
        // Decode base64 file content
        const fileBuffer = Buffer.from(fileContent, 'base64')

        const now = new Date()
        const safeFilePath = filePath.replace(/^\//, '')
        if (safeFilePath.includes('..')) {
          return errorResponse('Invalid file path', 400)
        }
        let effectiveLocalPath =
          (body as any).localPath && typeof (body as any).localPath === 'string'
            ? ((body as any).localPath as string)
            : safeFilePath

        // Ensure path starts with / (absolute path)
        if (!effectiveLocalPath.startsWith('/')) {
          effectiveLocalPath = '/' + effectiveLocalPath
        }

        // Normalize .netplay paths to canonical paths (don't store .netplay in DB)
        // This prevents .netplay uploads from overwriting canonical paths
        if (effectiveLocalPath.match('/\\.netplay/')) {
          const normalized = effectiveLocalPath.replace('/\\.netplay/', '/')
          console.log(`[Upload] Normalizing .netplay path: ${effectiveLocalPath} -> ${normalized}`)
          effectiveLocalPath = normalized
        }

        const providedSaveKey =
          (body as any).saveKey && typeof (body as any).saveKey === 'string'
            ? ((body as any).saveKey as string)
            : null

        const normalizedSaveKey = (providedSaveKey || safeFilePath)
          .replace(/\\/g, '/')
          .replace(/\s+/g, ' ')
          .trim()

        const hashHex =
          typeof (body as any).contentHash === 'string' && (body as any).contentHash.length > 0
            ? ((body as any).contentHash as string)
            : crypto.createHash('sha256').update(fileBuffer).digest('hex')

        const localModifiedAtRaw = (body as any).localModifiedAt
        let localModifiedAt: Date
        if (typeof localModifiedAtRaw === 'number' && localModifiedAtRaw > 0) {
          localModifiedAt = new Date(localModifiedAtRaw)
          console.log(`[Upload] Using client-provided mtime: ${localModifiedAt.toISOString()} (${localModifiedAtRaw}ms)`)
        } else if (typeof localModifiedAtRaw === 'string' && localModifiedAtRaw.length > 0) {
          localModifiedAt = new Date(localModifiedAtRaw)
          console.log(`[Upload] Using client-provided mtime (string): ${localModifiedAt.toISOString()}`)
        } else {
          localModifiedAt = now
          console.log(`[Upload] WARNING: No valid localModifiedAt provided, using upload time: ${now.toISOString()}`)
        }

        // Validate timestamp - clamp future timestamps and very old timestamps
        const MAX_FUTURE_MS = 60 * 60 * 1000 // 1 hour tolerance for clock drift
        const MIN_VALID_YEAR = 2020 // Anything before 2020 is suspicious
        const minValidMs = new Date('2020-01-01T00:00:00Z').getTime()

        if (localModifiedAt.getTime() > now.getTime() + MAX_FUTURE_MS) {
          // Future timestamp - likely filesystem corruption (common on retro handhelds)
          console.warn(
            `[Upload] Clamping future timestamp to now: ${localModifiedAt.toISOString()} ` +
            `(${localModifiedAt.getTime() - now.getTime()}ms in the future) -> ${now.toISOString()}`
          )
          localModifiedAt = now
        } else if (localModifiedAt.getTime() < minValidMs) {
          // Very old timestamp - device clock was probably wrong
          console.warn(
            `[Upload] Clamping old timestamp to now: ${localModifiedAt.toISOString()} ` +
            `(before ${MIN_VALID_YEAR}) -> ${now.toISOString()}`
          )
          localModifiedAt = now
        }

        // Create/resolve logical Save
        const save = await prisma.save.upsert({
          where: {
            userId_saveKey: {
              userId: device.userId,
              saveKey: normalizedSaveKey,
            },
          },
          create: {
            userId: device.userId,
            saveKey: normalizedSaveKey,
            displayName: safeFilePath.split('/').pop() || safeFilePath,
          },
          update: {
            displayName: safeFilePath.split('/').pop() || safeFilePath,
          },
        })

        // Ensure per-device-per-path mapping exists
        // Now supports multiple paths per device (e.g., different cores for same game)
        // IMPORTANT: Only set localPath on CREATE, never UPDATE (preserve original path)
        const saveLocation = await prisma.saveLocation.upsert({
          where: {
            saveId_deviceId_localPath: {
              saveId: save.id,
              deviceId: device.id,
              localPath: effectiveLocalPath,
            },
          },
          create: {
            saveId: save.id,
            deviceId: device.id,
            deviceType: device.deviceType,
            localPath: effectiveLocalPath,
            syncEnabled: true, // Default to enabled for new locations
          },
          update: {
            deviceType: device.deviceType,
            // DO NOT update localPath - preserve the original path for this device
          },
        })

        // Check if sync is disabled for this save on this device
        if (!saveLocation.syncEnabled) {
          console.log(`[Upload] Skipping upload for ${normalizedSaveKey} - sync disabled for device ${device.id}`)
          return successResponse({
            message: 'Upload skipped - sync disabled for this save',
            skipped: true,
            saveId: save.id,
          })
        }

        // Check if ANY version (across all devices) already has this exact content hash
        // This prevents duplicate S3 uploads when the same file is uploaded from different paths
        const existingVersionWithSameHash = await prisma.saveVersion.findFirst({
          where: {
            saveId: save.id,
            contentHash: hashHex,
          },
          orderBy: { uploadedAt: 'desc' },
        })

        if (existingVersionWithSameHash) {
          console.log(
            `[Upload] Content already exists for save ${save.id} (hash=${hashHex.slice(0, 8)}...), ` +
            `path ${effectiveLocalPath} added but no new version created`
          )

          await prisma.syncLog.create({
            data: {
              deviceId: device.id,
              action,
              filePath: safeFilePath,
              fileSize: typeof fileSize === 'number' ? fileSize : fileBuffer.length,
              status: 'skipped',
              errorMsg: 'Content already exists (path registered)',
              saveId: save.id,
              saveVersionId: existingVersionWithSameHash.id,
            },
          })

          return successResponse({
            message: 'Path registered - content already exists',
            skipped: true,
            uploaded: false,
            pathAdded: true,
            saveId: save.id,
            saveVersionId: existingVersionWithSameHash.id,
            contentHash: hashHex,
          })
        }

        // If the latest known version for this device/save already has the same
        // content hash and (roughly) the same mtime/size, treat this as a no-op
        // and report it as "skipped" so the client can show 0 changed files.
        const latestForDevice = await prisma.saveVersion.findFirst({
          where: {
            saveId: save.id,
            deviceId: device.id,
          },
          orderBy: { localModifiedAt: 'desc' },
        })

        if (latestForDevice) {
          const MTIME_EPSILON_MS = 2000 // 2s tolerance for clock/FS granularity
          const previousMs = latestForDevice.localModifiedAt.getTime()
          const currentMs = localModifiedAt.getTime()
          const mtimeClose = Math.abs(currentMs - previousMs) <= MTIME_EPSILON_MS
          const sameHash = latestForDevice.contentHash === hashHex
          const sameSize =
            latestForDevice.byteSize ===
            (typeof fileSize === 'number' ? fileSize : fileBuffer.length)

          // Check if this upload is significantly older than what we already have
          // This prevents overwriting newer saves with older ones
          const isOlder = currentMs < previousMs - MTIME_EPSILON_MS
          if (isOlder) {
            console.log(
              `[Upload] Rejecting older version for save ${save.id} on device ${device.id}: ` +
              `incoming mtime=${localModifiedAt.toISOString()} (${currentMs}ms) ` +
              `is older than existing=${latestForDevice.localModifiedAt.toISOString()} (${previousMs}ms)`
            )

            await prisma.syncLog.create({
              data: {
                deviceId: device.id,
                action,
                filePath: safeFilePath,
                fileSize: typeof fileSize === 'number' ? fileSize : fileBuffer.length,
                status: 'skipped',
                errorMsg: `Upload rejected: file is older than existing version (${previousMs - currentMs}ms older)`,
                saveId: save.id,
                saveVersionId: latestForDevice.id,
              },
            })

            return successResponse({
              message: 'Upload skipped - file is older than existing version',
              skipped: true,
              uploaded: false,
              saveId: save.id,
              saveVersionId: latestForDevice.id,
              contentHash: hashHex,
            })
          }

          if (mtimeClose && sameHash && sameSize) {
            console.log(
              `[Upload] Skipping unchanged content for save ${save.id} on device ${device.id}`
            )

            await prisma.syncLog.create({
              data: {
                deviceId: device.id,
                action,
                filePath: safeFilePath,
                fileSize: typeof fileSize === 'number' ? fileSize : fileBuffer.length,
                status: 'skipped',
                saveId: save.id,
                saveVersionId: latestForDevice.id,
              },
            })

            return successResponse({
              message: 'Upload skipped - content unchanged',
              skipped: true,
              uploaded: false,
              saveId: save.id,
              saveVersionId: latestForDevice.id,
              contentHash: hashHex,
            })
          }
        }

        // Create SaveVersion with deterministic storage key
        const saveVersionId = crypto.randomUUID()
        s3Key = `${device.userId}/saves/${save.id}/versions/${saveVersionId}`

        await prisma.saveVersion.create({
          data: {
            id: saveVersionId,
            saveId: save.id,
            deviceId: device.id,
            contentHash: hashHex,
            byteSize: typeof fileSize === 'number' ? fileSize : fileBuffer.length,
            localModifiedAt,
            storageKey: s3Key,
            uploadedAt: now,
          },
        })

        // Upload bytes to S3 after metadata is created
        await uploadFile(s3Key, fileBuffer)
        uploadSuccess = true

        // Log the sync event and link it to save/version
        await prisma.syncLog.create({
          data: {
            deviceId: device.id,
            action,
            filePath: safeFilePath,
            fileSize: typeof fileSize === 'number' ? fileSize : fileBuffer.length,
            status: 'success',
            saveId: save.id,
            saveVersionId: saveVersionId,
          },
        })

        return successResponse({
          message: 'File uploaded and indexed successfully',
          s3Key,
          uploaded: true,
          saveId: save.id,
          saveVersionId,
          contentHash: hashHex,
        })
      } catch (s3Error) {
        console.error('S3 upload error:', s3Error)
        // Continue to log the sync event even if S3 upload fails
      }
    }

    // Log the sync event (legacy / failure path)
    await prisma.syncLog.create({
      data: {
        deviceId: device.id,
        action,
        filePath: filePath.replace(/^\//, ''),
        fileSize: (typeof fileSize === 'number' ? fileSize : 0) || 0,
        status: uploadSuccess ? 'success' : 'failed',
      },
    })

    return successResponse({
      message: uploadSuccess
        ? 'File uploaded and logged successfully'
        : 'File sync logged (upload may have failed)',
      s3Key: s3Key,
      uploaded: uploadSuccess,
    })
  } catch (error) {
    console.error('Upload file error:', error)
    return errorResponse('Failed to upload file', 500)
  }
}
