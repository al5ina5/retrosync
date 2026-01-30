import { NextRequest } from 'next/server'
import { prisma } from '@/lib/prisma'
import { successResponse, errorResponse } from '@/lib/utils'

/**
 * GET /api/debug/db-test
 *
 * Simple health check for database connectivity:
 * - runs a lightweight query (count pairing codes)
 */
export async function GET(_request: NextRequest) {
  try {
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
