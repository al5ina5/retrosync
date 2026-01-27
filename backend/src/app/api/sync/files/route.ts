import { NextRequest } from 'next/server'
import { prisma } from '@/lib/prisma'
import { extractApiKey } from '@/lib/auth'
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/utils'
import { listFiles } from '@/lib/s3'

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
    const emulatorType = searchParams.get('emulator')
    const gameId = searchParams.get('game')

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
 * POST /api/sync/files - Upload file metadata (actual file goes to S3 directly)
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
    const { filePath, fileSize, action } = body

    if (!filePath || !action) {
      return errorResponse('filePath and action are required')
    }

    // Log the sync event
    await prisma.syncLog.create({
      data: {
        deviceId: device.id,
        action,
        filePath,
        fileSize: fileSize || 0,
        status: 'success',
      },
    })

    return successResponse({
      message: 'File sync logged successfully',
    })
  } catch (error) {
    console.error('Upload file metadata error:', error)
    return errorResponse('Failed to log file sync', 500)
  }
}
