import { NextRequest } from 'next/server'
import { prisma } from '@/lib/prisma'
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/utils'

/**
 * GET /api/debug/db-test
 *
 * Simple health check for database connectivity:
 * - runs a lightweight query (count pairing codes)
 */
export async function GET(_request: NextRequest) {
  try {
    if (!isDebugAllowed(_request)) {
      return unauthorizedResponse()
    }
    await prisma.pairingCode.count()
    return successResponse(
      { ok: true },
      'Database health check passed'
    )
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err)
    console.error('DB healthcheck error:', err)
    return errorResponse(`Database health check failed: ${message}`, 500)
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
