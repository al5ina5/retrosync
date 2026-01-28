import { NextRequest } from 'next/server'

type RateLimitKey = string

interface RateLimitEntry {
  count: number
  resetAt: number
}

// Very simple in-memory rate limiter. This is mainly a safety net and may not
// be effective in all deployment topologies (e.g. serverless with many cold
// starts), but it provides basic protection without impacting normal users.
const rateLimitStore = new Map<RateLimitKey, RateLimitEntry>()

function getClientIp(req: NextRequest): string {
  // Prefer x-forwarded-for if present, fall back to NextRequest.ip
  const xff = req.headers.get('x-forwarded-for')
  if (xff) {
    return xff.split(',')[0]?.trim() || 'unknown'
  }
  return (req as any).ip || 'unknown'
}

export interface RateLimitOptions {
  windowMs: number
  max: number
  keyPrefix?: string
}

export function checkRateLimit(
  req: NextRequest,
  { windowMs, max, keyPrefix = 'rl' }: RateLimitOptions
): { allowed: boolean; remaining: number; resetAt: number } {
  const ip = getClientIp(req)
  const key: RateLimitKey = `${keyPrefix}:${ip}`
  const now = Date.now()

  const existing = rateLimitStore.get(key)

  if (!existing || existing.resetAt <= now) {
    const entry: RateLimitEntry = {
      count: 1,
      resetAt: now + windowMs,
    }
    rateLimitStore.set(key, entry)
    return { allowed: true, remaining: max - 1, resetAt: entry.resetAt }
  }

  if (existing.count >= max) {
    return { allowed: false, remaining: 0, resetAt: existing.resetAt }
  }

  existing.count += 1
  rateLimitStore.set(key, existing)

  return { allowed: true, remaining: Math.max(0, max - existing.count), resetAt: existing.resetAt }
}

