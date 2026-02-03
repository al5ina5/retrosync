import { NextRequest } from 'next/server'
import { prisma } from '@/lib/prisma'
import { extractApiKey } from '@/lib/auth'
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/utils'

function normalizePath(input: string): string {
  let path = input.trim()
  if (path === '') return path
  const windowsRoot = /^[a-zA-Z]:[\\/]?$/
  if (path === '/' || windowsRoot.test(path)) {
    return path
  }
  path = path.replace(/[\\/]+$/, '')
  return path
}

/**
 * POST /api/sync/heartbeat - Device check-in
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

    const body = await request.json().catch(() => ({}))
    const scanPathsRaw = Array.isArray(body?.scanPaths) ? body.scanPaths : null

    if (scanPathsRaw) {
      const allowedKinds = new Set(['default', 'custom'])
      const seen = new Set<string>()
      const sanitized: { path: string; kind: 'default' | 'custom' }[] = []

      for (const entry of scanPathsRaw) {
        if (!entry || typeof entry !== 'object') continue
        const rawPath = (entry as any).path
        const rawKind = (entry as any).kind
        if (typeof rawPath !== 'string') continue
        if (!allowedKinds.has(rawKind)) continue
        let normalized = normalizePath(rawPath)
        if (!normalized) continue
        if (normalized.length > 1024) continue
        const key = `${rawKind}:${normalized}`
        if (seen.has(key)) continue
        seen.add(key)
        sanitized.push({ path: normalized, kind: rawKind })
        if (sanitized.length >= 200) break
      }

      const defaultPaths = sanitized.filter((p) => p.kind === 'default').map((p) => p.path)
      const customDevicePaths = sanitized.filter((p) => p.kind === 'custom').map((p) => p.path)

      const ops: any[] = []

      for (const path of defaultPaths) {
        ops.push(
          prisma.deviceScanPath.upsert({
            where: {
              deviceId_path_kind: {
                deviceId: device.id,
                path,
                kind: 'default',
              },
            },
            update: {
              source: 'device',
            },
            create: {
              deviceId: device.id,
              path,
              kind: 'default',
              source: 'device',
            },
          })
        )
      }

      for (const path of customDevicePaths) {
        ops.push(
          prisma.deviceScanPath.upsert({
            where: {
              deviceId_path_kind: {
                deviceId: device.id,
                path,
                kind: 'custom',
              },
            },
            update: {
              source: 'device',
            },
            create: {
              deviceId: device.id,
              path,
              kind: 'custom',
              source: 'device',
            },
          })
        )
      }

      if (defaultPaths.length > 0) {
        ops.push(
          prisma.deviceScanPath.deleteMany({
            where: {
              deviceId: device.id,
              kind: 'default',
              path: { notIn: defaultPaths },
            },
          })
        )
      }

      if (customDevicePaths.length > 0) {
        ops.push(
          prisma.deviceScanPath.deleteMany({
            where: {
              deviceId: device.id,
              kind: 'custom',
              source: 'device',
              path: { notIn: customDevicePaths },
            },
          })
        )
      }

      if (ops.length > 0) {
        await prisma.$transaction(ops)
      }
    }

    // Update last sync time
    await prisma.device.update({
      where: { id: device.id },
      data: {
        lastSyncAt: new Date(),
        isActive: true,
      },
    })

    const scanPaths = await prisma.deviceScanPath.findMany({
      where: { deviceId: device.id },
      orderBy: [{ kind: 'desc' }, { path: 'asc' }],
    })

    return successResponse({
      deviceId: device.id,
      deviceName: device.name,
      lastSyncAt: new Date(),
      scanPaths,
    }, 'Heartbeat received')
  } catch (error) {
    console.error('Heartbeat error:', error)
    return errorResponse('Failed to process heartbeat', 500)
  }
}
