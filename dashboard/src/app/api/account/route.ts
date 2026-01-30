import { NextRequest } from "next/server";
import { getUserFromRequest, hashPassword, verifyPassword } from "@/lib/auth";
import { prisma } from "@/lib/prisma";
import { deleteFile } from "@/lib/s3";
import { stripe } from "@/lib/stripe";
import {
  successResponse,
  errorResponse,
  unauthorizedResponse,
  serverErrorResponse,
} from "@/lib/utils";
import { z } from "zod";

const deleteBodySchema = z.object({
  password: z.string().min(1, "Password is required"),
});

const patchBodySchema = z
  .object({
    name: z.string().max(200).optional(),
    email: z.string().email().optional(),
    currentPassword: z.string().min(1).optional(),
    newPassword: z.string().min(8, "Password must be at least 8 characters").optional(),
  })
  .refine(
    (data) => {
      if (data.newPassword != null) return data.currentPassword != null;
      return true;
    },
    { message: "Current password required to set new password", path: ["currentPassword"] }
  );

export async function GET(request: NextRequest) {
  const payload = getUserFromRequest(request);
  if (!payload || payload.type !== "user") {
    return unauthorizedResponse();
  }

  const user = await prisma.user.findUnique({
    where: { id: payload.userId },
    select: { subscriptionTier: true, email: true, name: true, createdAt: true },
  });

  if (!user) {
    return errorResponse("User not found", 404);
  }

  return successResponse({
    subscriptionTier: user.subscriptionTier,
    email: user.email,
    name: user.name ?? "",
    createdAt: user.createdAt.toISOString(),
  });
}

export async function PATCH(request: NextRequest) {
  const payload = getUserFromRequest(request);
  if (!payload || payload.type !== "user") {
    return unauthorizedResponse();
  }

  const userId = payload.userId;

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return errorResponse("Invalid JSON", 400);
  }

  const parsed = patchBodySchema.safeParse(body);
  if (!parsed.success) {
    const msg = parsed.error.errors[0]?.message ?? "Validation failed";
    return errorResponse(msg, 400);
  }

  const { name, email, currentPassword, newPassword } = parsed.data;

  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { id: true, email: true, passwordHash: true },
  });

  if (!user) {
    return errorResponse("User not found", 404);
  }

  const updates: { name?: string; email?: string; passwordHash?: string } = {};

  if (name !== undefined) {
    updates.name = name;
  }

  if (email !== undefined) {
    const existing = await prisma.user.findUnique({
      where: { email },
      select: { id: true },
    });
    if (existing && existing.id !== userId) {
      return errorResponse("Email already in use", 400);
    }
    updates.email = email;
  }

  if (newPassword !== undefined && currentPassword !== undefined) {
    const valid = await verifyPassword(currentPassword, user.passwordHash);
    if (!valid) {
      return errorResponse("Current password is incorrect", 401);
    }
    updates.passwordHash = await hashPassword(newPassword);
  }

  if (Object.keys(updates).length === 0) {
    return errorResponse("No updates provided", 400);
  }

  try {
    await prisma.user.update({
      where: { id: userId },
      data: updates,
    });
    return successResponse({ ok: true });
  } catch (e) {
    console.error("Account PATCH error:", e);
    return serverErrorResponse();
  }
}

export async function DELETE(request: NextRequest) {
  const payload = getUserFromRequest(request);
  if (!payload || payload.type !== "user") {
    return unauthorizedResponse();
  }

  const userId = payload.userId;

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return errorResponse("Invalid JSON", 400);
  }

  const parsed = deleteBodySchema.safeParse(body);
  if (!parsed.success) {
    const msg = parsed.error.errors[0]?.message ?? "Validation failed";
    return errorResponse(msg, 400);
  }

  const { password } = parsed.data;

  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: {
      id: true,
      passwordHash: true,
      stripeCustomerId: true,
      saves: {
        include: {
          versions: { select: { storageKey: true } },
        },
      },
    },
  });

  if (!user) {
    return errorResponse("User not found", 404);
  }

  const valid = await verifyPassword(password, user.passwordHash);
  if (!valid) {
    return errorResponse("Incorrect password", 401);
  }

  try {
    // Delete S3 files for all save versions
    for (const save of user.saves) {
      for (const version of save.versions) {
        if (version.storageKey) {
          await deleteFile(version.storageKey).catch((err) => {
            console.warn("Failed to delete S3 file:", version.storageKey, err);
          });
        }
      }
    }

    // Delete records in order (avoid FK violations)
    const saveIds = user.saves.map((s) => s.id);
    if (saveIds.length > 0) {
      await prisma.syncLog.deleteMany({ where: { saveId: { in: saveIds } } });
      await prisma.saveVersion.deleteMany({ where: { saveId: { in: saveIds } } });
      await prisma.saveLocation.deleteMany({ where: { saveId: { in: saveIds } } });
      await prisma.save.deleteMany({ where: { id: { in: saveIds } } });
    }

    // Delete devices (cascades syncLogs, etc.) and pairing codes
    await prisma.device.deleteMany({ where: { userId } });
    await prisma.pairingCode.deleteMany({ where: { userId } });

    // Cancel Stripe subscriptions if present
    if (user.stripeCustomerId && stripe) {
      try {
        const subs = await stripe.subscriptions.list({
          customer: user.stripeCustomerId,
          status: "active",
        });
        for (const sub of subs.data) {
          await stripe.subscriptions.cancel(sub.id);
        }
      } catch (e) {
        console.warn("Stripe cancel on delete:", e);
      }
    }

    await prisma.user.delete({ where: { id: userId } });
    return successResponse({ ok: true });
  } catch (e) {
    console.error("Account DELETE error:", e);
    return serverErrorResponse();
  }
}
