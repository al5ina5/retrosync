import { prisma } from "@/lib/prisma";

export const FREE_MAX_DEVICES = 2;
export const FREE_MAX_SHARED_SAVES = 3;

export function isPaidTier(tier?: string | null): boolean {
  return tier === "paid";
}

async function getUserTier(userId: string): Promise<string | null> {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { subscriptionTier: true },
  });
  return user?.subscriptionTier ?? null;
}

export async function canAddDevice(userId: string): Promise<{
  allowed: boolean;
  reason?: string;
  count?: number;
}> {
  const tier = await getUserTier(userId);
  if (isPaidTier(tier)) return { allowed: true };

  const count = await prisma.device.count({ where: { userId } });
  if (count >= FREE_MAX_DEVICES) {
    return {
      allowed: false,
      reason: `Free plan allows up to ${FREE_MAX_DEVICES} devices. Upgrade to add more.`,
      count,
    };
  }
  return { allowed: true, count };
}

export async function canEnableSharedSave(
  userId: string,
  excludeSaveId?: string | null
): Promise<{ allowed: boolean; reason?: string; count?: number }> {
  const tier = await getUserTier(userId);
  if (isPaidTier(tier)) return { allowed: true };

  const where: Record<string, unknown> = {
    userId,
    syncStrategy: "shared",
  };
  if (excludeSaveId) {
    where.id = { not: excludeSaveId };
  }

  const count = await prisma.save.count({ where });
  if (count >= FREE_MAX_SHARED_SAVES) {
    return {
      allowed: false,
      reason: `Free plan allows up to ${FREE_MAX_SHARED_SAVES} shared saves. Upgrade to sync more games across devices.`,
      count,
    };
  }

  return { allowed: true, count };
}
