import { NextRequest } from "next/server";
import { getUserFromRequest } from "@/lib/auth";
import { stripe } from "@/lib/stripe";
import { prisma } from "@/lib/prisma";
import {
  successResponse,
  errorResponse,
  unauthorizedResponse,
} from "@/lib/utils";

export async function GET(request: NextRequest) {
  const user = getUserFromRequest(request);
  if (!user || user.type !== "user") {
    return unauthorizedResponse();
  }

  const sessionId = request.nextUrl.searchParams.get("session_id");
  if (!sessionId) {
    return errorResponse("Missing session_id", 400);
  }

  if (!stripe) {
    return errorResponse("Payments are not configured", 503);
  }

  const session = await stripe.checkout.sessions.retrieve(sessionId);
  if (session.payment_status !== "paid") {
    return errorResponse("Session not paid", 403);
  }
  if (session.client_reference_id !== user.userId) {
    return errorResponse("Session does not belong to this user", 403);
  }

  const customerId =
    typeof session.customer === "string"
      ? session.customer
      : session.customer?.id ?? null;
  await prisma.user.update({
    where: { id: user.userId },
    data: {
      subscriptionTier: "paid",
      ...(customerId && { stripeCustomerId: customerId }),
    },
  });

  return successResponse({ ok: true });
}
