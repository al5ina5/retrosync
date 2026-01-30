import { NextRequest } from "next/server";
import { getUserFromRequest } from "@/lib/auth";
import { stripe } from "@/lib/stripe";
import { prisma } from "@/lib/prisma";
import {
  successResponse,
  errorResponse,
  unauthorizedResponse,
} from "@/lib/utils";

export async function POST(request: NextRequest) {
  const payload = getUserFromRequest(request);
  if (!payload || payload.type !== "user") {
    return unauthorizedResponse();
  }

  if (!stripe) {
    return errorResponse("Payments are not configured", 503);
  }

  const user = await prisma.user.findUnique({
    where: { id: payload.userId },
    select: { stripeCustomerId: true },
  });

  if (!user?.stripeCustomerId) {
    return errorResponse("No billing account found. Upgrade first to manage your subscription.", 400);
  }

  const origin =
    request.headers.get("origin") ??
    `${request.headers.get("x-forwarded-proto") ?? "https"}://${request.headers.get("host") ?? "localhost:3000"}`;
  const baseUrl = origin.startsWith("http") ? origin : `https://${origin}`;
  const returnUrl = `${baseUrl}/account`;

  const session = await stripe.billingPortal.sessions.create({
    customer: user.stripeCustomerId,
    return_url: returnUrl,
  });

  if (!session.url) {
    return errorResponse("Failed to create portal session", 500);
  }

  return successResponse({ url: session.url });
}
