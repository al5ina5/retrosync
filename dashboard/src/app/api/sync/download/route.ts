import { NextRequest } from 'next/server'
import { prisma } from '@/lib/prisma'
import { extractApiKey } from '@/lib/auth'
import { errorResponse, successResponse, unauthorizedResponse } from '@/lib/utils'
import { downloadFile } from '@/lib/s3'

/**
 * GET /api/sync/download?saveVersionId=...
 * Downloads the bytes for a specific SaveVersion owned by the same user.
 */
export async function GET(request: NextRequest) {
  try {
    const apiKey = extractApiKey(request)
    if (!apiKey) return unauthorizedResponse('API key is required')

    const device = await prisma.device.findUnique({
      where: { apiKey },
    })
    if (!device) return unauthorizedResponse('Invalid API key')

    const { searchParams } = new URL(request.url)
    const saveVersionId = searchParams.get('saveVersionId')
    if (!saveVersionId) return errorResponse('saveVersionId is required', 400)

    const saveVersion = await prisma.saveVersion.findUnique({
      where: { id: saveVersionId },
      include: { save: true },
    })
    if (!saveVersion || saveVersion.save.userId !== device.userId) {
      return unauthorizedResponse('Save version not found')
    }

    const bytes = await downloadFile(saveVersion.storageKey)

    // Best-effort log
    prisma.syncLog
      .create({
        data: {
          deviceId: device.id,
          action: 'download',
          filePath: saveVersion.save.displayName,
          fileSize: saveVersion.byteSize,
          status: 'success',
          saveId: saveVersion.saveId,
          saveVersionId: saveVersion.id,
        },
      })
      .catch((e) => console.warn('Failed to log download:', e))

    return new Response(bytes, {
      status: 200,
      headers: {
        'content-type': 'application/octet-stream',
        'content-length': String(bytes.length),
        'x-save-id': saveVersion.saveId,
        'x-save-version-id': saveVersion.id,
        'x-save-hash': saveVersion.contentHash,
        'x-save-local-modified-at': saveVersion.localModifiedAt.toISOString(),
        'x-save-uploaded-at': saveVersion.uploadedAt.toISOString(),
      },
    })
  } catch (err) {
    console.error('Download error:', err)
    return errorResponse('Failed to download file', 500)
  }
}

// Dummy export so eslint/tsc doesn’t complain about unused imports in some configs
export const _ok = successResponse

