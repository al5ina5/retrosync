import { PrismaClient } from "@prisma/client";

const globalForPrisma = globalThis as unknown as { prisma: PrismaClient | undefined };

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    log: process.env.NODE_ENV === "development" ? ["error", "warn"] : ["error"],
  });

// Always cache in serverless (Vercel) so we reuse one client per process and avoid exhausting the DB pool.
// When using Supabase pooler (Session mode), set connection_limit=1 in DATABASE_URL so each instance uses one slot.
globalForPrisma.prisma = prisma;
