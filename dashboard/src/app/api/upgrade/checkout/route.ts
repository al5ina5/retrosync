import { NextRequest } from "next/server";
import { getUserFromRequest } from "@/lib/auth";
import { getOrCreateUpgradePriceId, stripe } from "@/lib/stripe";
import { prisma } from "@/lib/prisma";
import {
  successResponse,
  errorResponse,
  unauthorizedResponse,
} from "@/lib/utils";

export async function POST(request: NextRequest) {
  const user = getUserFromRequest(request);
  if (!user || user.type !== "user") {
    return unauthorizedResponse();
  }

  if (!stripe) {
    return errorResponse("Payments are not configured", 503);
  }

  const priceId = await getOrCreateUpgradePriceId();
  if (!priceId) {
    return errorResponse("Could not create or find subscription price", 500);
  }

  const origin =
    request.headers.get("origin") ??
    `${request.headers.get("x-forwarded-proto") ?? "https"}://${request.headers.get("host") ?? "localhost:3000"}`;

  const baseUrl = origin.startsWith("http") ? origin : `https://${origin}`;

  const session = await stripe.checkout.sessions.create({
    mode: "subscription",
    line_items: [{ price: priceId, quantity: 1 }],
    success_url: `${baseUrl}/upgrade/complete?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${baseUrl}/upgrade`,
    client_reference_id: user.userId,
    customer_email: user.email,
  });

  if (!session.url) {
    return errorResponse("Failed to create checkout session", 500);
  }

  return successResponse({ url: session.url });
}
