import { NextRequest } from 'next/server'
import { uploadFile, fileExists, deleteFile, BUCKET_NAME } from '@/lib/s3'
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/utils'

/**
 * GET /api/debug/s3-test
 *
 * Simple health check for S3/MinIO/Supabase storage:
 * - uploads a tiny text object
 * - verifies it exists
 * - deletes it
 */
export async function GET(_request: NextRequest) {
  const key = `s3-healthcheck/test-${Date.now()}.txt`
  const body = Buffer.from('retrosync s3 health check', 'utf8')

  try {
    if (!isDebugAllowed(_request)) {
      return unauthorizedResponse()
    }
    // Upload
    await uploadFile(key, body, 'text/plain')

    // Verify it exists
    const exists = await fileExists(key)
    if (!exists) {
      return errorResponse('S3 test upload did not appear in bucket', 500)
    }

    // Clean up
    await deleteFile(key)

    return successResponse(
      {
        bucket: BUCKET_NAME,
        key,
      },
      'S3 storage health check passed'
    )
  } catch (err) {
    console.error('S3 healthcheck error:', err)
    return errorResponse('S3 storage health check failed', 500)
  }
}

function isDebugAllowed(request: NextRequest): boolean {
  if (process.env.NODE_ENV !== 'production') return true
  const token = process.env.DEBUG_TOKEN
  if (!token) return false
  const headerToken = request.headers.get('x-debug-token')
  if (headerToken && headerToken === token) return true
  const auth = request.headers.get('authorization')
  if (auth && auth.startsWith('Bearer ') && auth.substring(7) === token) return true
  return false
}
