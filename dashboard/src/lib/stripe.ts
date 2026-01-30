import Stripe from "stripe";

const secret = process.env.STRIPE_SECRET_KEY;
export const stripe = secret ? new Stripe(secret) : null;

export const PUBLISHABLE_KEY = process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY ?? process.env.STRIPE_PUBLISHABLE_KEY ?? "";

const PRODUCT_NAME = "RetroSync Pro";
const PRICE_AMOUNT_CENTS = 600; // $6/mo
const PRICE_INTERVAL: "month" = "month";

/** Get or create the $6/mo subscription product and price. Returns the Stripe Price ID. */
export async function getOrCreateUpgradePriceId(): Promise<string | null> {
  if (!stripe) return null;

  const products = await stripe.products.list({ limit: 100 });
  let product = products.data.find((p) => p.name === PRODUCT_NAME);

  if (!product) {
    product = await stripe.products.create({
      name: PRODUCT_NAME,
      description: "RetroSync premium — unlimited devices, saves, and syncs.",
    });
  }

  const prices = await stripe.prices.list({
    product: product.id,
    active: true,
    limit: 100,
  });
  let price = prices.data.find(
    (p) =>
      p.recurring?.interval === PRICE_INTERVAL &&
      p.unit_amount === PRICE_AMOUNT_CENTS
  );

  if (!price) {
    price = await stripe.prices.create({
      product: product.id,
      unit_amount: PRICE_AMOUNT_CENTS,
      currency: "usd",
      recurring: { interval: PRICE_INTERVAL },
    });
  }

  return price.id;
}
