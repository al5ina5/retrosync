import { NextRequest } from "next/server";
import Stripe from "stripe";
import { stripe } from "@/lib/stripe";
import { prisma } from "@/lib/prisma";

// Required for signature verification. Get it from Stripe Dashboard → Developers → Webhooks → Add endpoint → signing secret.
const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;
if (!webhookSecret && process.env.NODE_ENV === "production") {
  console.warn("STRIPE_WEBHOOK_SECRET is not set; webhook will not verify");
}

export async function POST(request: NextRequest) {
  if (!stripe) {
    return new Response("Payments not configured", { status: 503 });
  }

  const rawBody = await request.text();
  const sig = request.headers.get("stripe-signature");
  if (!sig || !webhookSecret) {
    return new Response("Missing signature or webhook secret", { status: 400 });
  }

  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(rawBody, sig, webhookSecret);
  } catch (err) {
    const message = err instanceof Error ? err.message : "Unknown error";
    console.error("Stripe webhook signature verification failed:", message);
    return new Response(`Webhook Error: ${message}`, { status: 400 });
  }

  if (event.type === "checkout.session.completed") {
    const session = event.data.object as Stripe.Checkout.Session;
    const userId = session.client_reference_id;
    const customerId = typeof session.customer === "string" ? session.customer : session.customer?.id;

    if (!userId) {
      console.error("checkout.session.completed missing client_reference_id");
      return new Response("OK", { status: 200 });
    }

    await prisma.user.update({
      where: { id: userId },
      data: {
        subscriptionTier: "paid",
        ...(customerId && { stripeCustomerId: customerId }),
      },
    });
  }

  return new Response("OK", { status: 200 });
}
