import { NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { extractApiKey, getUserFromRequest } from "@/lib/auth";
import { errorResponse, successResponse, unauthorizedResponse } from "@/lib/utils";
import { z } from "zod";

const addSchema = z.object({
  deviceId: z.string().min(1, "deviceId is required"),
  path: z.string().min(1, "path is required"),
});

function normalizePath(input: string): string {
  let path = input.trim();
  if (path === "") return path;
  const windowsRoot = /^[a-zA-Z]:[\\/]?$/;
  if (path === "/" || windowsRoot.test(path)) {
    return path;
  }
  path = path.replace(/[\\/]+$/, "");
  return path;
}

async function getDeviceForUser(userId: string, deviceId: string) {
  return prisma.device.findFirst({
    where: {
      id: deviceId,
      userId,
    },
  });
}

/**
 * GET /api/devices/scan-paths - List scan paths for a device (user) or self (device API key)
 */
export async function GET(request: NextRequest) {
  try {
    const apiKey = extractApiKey(request);
    if (apiKey) {
      const device = await prisma.device.findUnique({
        where: { apiKey },
      });
      if (!device) return unauthorizedResponse("Invalid API key");
      const paths = await prisma.deviceScanPath.findMany({
        where: { deviceId: device.id },
        orderBy: [{ kind: "desc" }, { path: "asc" }],
      });
      return successResponse({ paths });
    }

    const user = getUserFromRequest(request);
    if (!user) return unauthorizedResponse();

    const { searchParams } = new URL(request.url);
    const deviceId = searchParams.get("deviceId");
    if (!deviceId) return errorResponse("deviceId is required");

    const device = await getDeviceForUser(user.userId, deviceId);
    if (!device) return errorResponse("Device not found", 404);

    const paths = await prisma.deviceScanPath.findMany({
      where: { deviceId: device.id },
      orderBy: [{ kind: "desc" }, { path: "asc" }],
    });

    return successResponse({ paths });
  } catch (error) {
    console.error("Fetch scan paths error:", error);
    return errorResponse("Failed to fetch scan paths", 500);
  }
}

/**
 * POST /api/devices/scan-paths - Add a custom scan path (dashboard only)
 */
export async function POST(request: NextRequest) {
  try {
    const user = getUserFromRequest(request);
    if (!user) return unauthorizedResponse();

    const body = await request.json().catch(() => ({}));
    const validation = addSchema.safeParse(body);
    if (!validation.success) {
      return errorResponse(validation.error.errors[0].message);
    }

    const normalized = normalizePath(validation.data.path);
    if (!normalized) return errorResponse("path is required");
    if (normalized.length > 1024) return errorResponse("path is too long");

    const device = await getDeviceForUser(user.userId, validation.data.deviceId);
    if (!device) return errorResponse("Device not found", 404);

    const path = await prisma.deviceScanPath.upsert({
      where: {
        deviceId_path_kind: {
          deviceId: device.id,
          path: normalized,
          kind: "custom",
        },
      },
      update: {
        source: "user",
      },
      create: {
        deviceId: device.id,
        path: normalized,
        kind: "custom",
        source: "user",
      },
    });

    return successResponse({ path });
  } catch (error) {
    console.error("Add scan path error:", error);
    return errorResponse("Failed to add scan path", 500);
  }
}

const deleteSchema = z.object({
  pathId: z.string().uuid("pathId must be a valid UUID"),
});

/**
 * DELETE /api/devices/scan-paths - Remove a custom scan path (dashboard only)
 */
export async function DELETE(request: NextRequest) {
  try {
    const user = getUserFromRequest(request);
    if (!user) return unauthorizedResponse();

    const { searchParams } = new URL(request.url);
    const pathId = searchParams.get("pathId");
    const validation = deleteSchema.safeParse({ pathId });
    if (!validation.success) {
      return errorResponse(validation.error.errors[0].message);
    }

    const scanPath = await prisma.deviceScanPath.findUnique({
      where: { id: validation.data.pathId },
      include: { device: true },
    });
    if (!scanPath) return errorResponse("Scan path not found", 404);
    if (scanPath.device.userId !== user.userId) {
      return errorResponse("Device not found", 404);
    }
    if (scanPath.kind !== "custom") {
      return errorResponse("Only custom paths can be removed");
    }

    await prisma.deviceScanPath.delete({
      where: { id: validation.data.pathId },
    });

    return successResponse({ success: true });
  } catch (error) {
    console.error("Delete scan path error:", error);
    return errorResponse("Failed to delete scan path", 500);
  }
}
