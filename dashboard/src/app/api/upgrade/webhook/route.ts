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
    const customerId =
      typeof session.customer === "string" ? session.customer : session.customer?.id;

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

  if (event.type === "customer.subscription.updated") {
    const subscription = event.data.object as Stripe.Subscription;
    const customerId =
      typeof subscription.customer === "string"
        ? subscription.customer
        : subscription.customer?.id ?? null;
    await setTierFromSubscription(customerId, subscription);
  }

  if (event.type === "customer.subscription.deleted") {
    const subscription = event.data.object as Stripe.Subscription;
    const customerId =
      typeof subscription.customer === "string"
        ? subscription.customer
        : subscription.customer?.id ?? null;
    await setTierFromSubscription(customerId, subscription);
  }

  if (
    event.type === "invoice.payment_failed" ||
    event.type === "invoice.payment_succeeded" ||
    event.type === "invoice.paid"
  ) {
    const invoice = event.data.object as Stripe.Invoice & {
      subscription?: string | Stripe.Subscription | null;
    };
    const customerId =
      typeof invoice.customer === "string" ? invoice.customer : invoice.customer?.id ?? null;
    if (!customerId) {
      return new Response("OK", { status: 200 });
    }

    const subscriptionId =
      typeof invoice.subscription === "string"
        ? invoice.subscription
        : invoice.subscription?.id ?? null;
    if (subscriptionId) {
      const subscription = await stripe.subscriptions.retrieve(subscriptionId);
      await setTierFromSubscription(customerId, subscription);
    } else if (event.type === "invoice.payment_succeeded" || event.type === "invoice.paid") {
      await setTierByCustomer(customerId, true);
    } else if (event.type === "invoice.payment_failed") {
      await setTierByCustomer(customerId, false);
    }
  }

  return new Response("OK", { status: 200 });
}

function isPaidStatus(status: Stripe.Subscription.Status): boolean {
  return status === "active" || status === "trialing";
}

async function setTierFromSubscription(
  customerId: string | null,
  subscription: Stripe.Subscription
) {
  await setTierByCustomer(customerId, isPaidStatus(subscription.status));
}

async function setTierByCustomer(customerId: string | null, paid: boolean) {
  if (!customerId) return;
  await prisma.user.updateMany({
    where: { stripeCustomerId: customerId },
    data: { subscriptionTier: paid ? "paid" : "free" },
  });
}
