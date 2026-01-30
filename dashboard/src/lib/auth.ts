import jwt, { SignOptions } from "jsonwebtoken";
import bcrypt from "bcryptjs";
import { NextRequest } from "next/server";
import crypto from "crypto";

const JWT_SECRET =
  process.env.JWT_SECRET ||
  (process.env.NODE_ENV !== "production"
    ? "your-super-secret-jwt-key-change-this-in-development-only"
    : (() => {
      throw new Error("JWT_SECRET must be set in production");
    })());

export interface JWTPayload {
  userId: string;
  email: string;
  type: "user" | "device";
  deviceId?: string;
}

export async function hashPassword(password: string): Promise<string> {
  return bcrypt.hash(password, 10);
}

export async function verifyPassword(
  password: string,
  hash: string
): Promise<boolean> {
  return bcrypt.compare(password, hash);
}

export function generateToken(
  payload: JWTPayload,
  expiresIn: string = "7d"
): string {
  return jwt.sign(payload, JWT_SECRET, { expiresIn } as SignOptions);
}

export function verifyToken(token: string): JWTPayload | null {
  try {
    return jwt.verify(token, JWT_SECRET) as JWTPayload;
  } catch {
    return null;
  }
}

export function extractToken(request: NextRequest): string | null {
  const authHeader = request.headers.get("authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) return null;
  return authHeader.substring(7);
}

export function getUserFromRequest(request: NextRequest): JWTPayload | null {
  const token = extractToken(request);
  if (!token) return null;
  return verifyToken(token);
}

export function generateApiKey(): string {
  return crypto.randomBytes(32).toString("hex");
}

export function generatePairingCode(): string {
  return crypto.randomInt(100000, 1000000).toString();
}

export function extractApiKey(request: NextRequest): string | null {
  return request.headers.get("x-api-key");
}
