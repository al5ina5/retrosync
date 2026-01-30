import { NextRequest } from "next/server";

interface RateLimitEntry {
  count: number;
  resetAt: number;
}

const rateLimitStore = new Map<string, RateLimitEntry>();

function getClientIp(req: NextRequest): string {
  const xff = req.headers.get("x-forwarded-for");
  if (xff) return xff.split(",")[0]?.trim() || "unknown";
  return (req as NextRequest & { ip?: string }).ip || "unknown";
}

export interface RateLimitOptions {
  windowMs: number;
  max: number;
  keyPrefix?: string;
}

export function checkRateLimit(
  req: NextRequest,
  { windowMs, max, keyPrefix = "rl" }: RateLimitOptions
): { allowed: boolean; remaining: number; resetAt: number } {
  const ip = getClientIp(req);
  const key = `${keyPrefix}:${ip}`;
  const now = Date.now();
  const existing = rateLimitStore.get(key);

  if (!existing || existing.resetAt <= now) {
    const entry = { count: 1, resetAt: now + windowMs };
    rateLimitStore.set(key, entry);
    return { allowed: true, remaining: max - 1, resetAt: entry.resetAt };
  }

  if (existing.count >= max) {
    return { allowed: false, remaining: 0, resetAt: existing.resetAt };
  }

  existing.count += 1;
  rateLimitStore.set(key, existing);
  return {
    allowed: true,
    remaining: Math.max(0, max - existing.count),
    resetAt: existing.resetAt,
  };
}
