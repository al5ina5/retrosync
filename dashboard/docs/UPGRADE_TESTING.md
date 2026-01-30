# Testing the upgrade / Stripe flow

Use **Stripe test mode** (keys starting with `pk_test_` / `sk_test_`). No real charges.

## 1. Run the dashboard

From the dashboard directory, with Stripe env vars set (e.g. in `dashboard/.env` or root `.env` if you run from repo root):

```bash
cd dashboard
npm run dev
```

Open **http://localhost:3000**.

## 2. Test checkout (no webhook needed)

1. **Sign in** (or register) so you have a user and JWT.
2. Go to **http://localhost:3000/upgrade**.
3. Click **“Upgrade for $6/mo”**. You should be redirected to **Stripe Checkout**.
4. Use Stripe’s test card:
   - **Card:** `4242 4242 4242 4242`
   - **Expiry:** any future date (e.g. `12/34`)
   - **CVC:** any 3 digits (e.g. `123`)
   - **ZIP:** any 5 digits (e.g. `12345`)
5. Complete the payment. Stripe redirects to **http://localhost:3000/upgrade/complete?session_id=...**.
6. The complete page verifies the session and shows the success message.

**Without the webhook**, the DB tier is not updated yet; the complete page still works because it only checks that the Checkout session is paid. To test tier updates (and future webhook-only logic), use the webhook with the CLI below.

## 3. Test the webhook (optional, for tier update)

Stripe can’t POST to `localhost`, so use the **Stripe CLI** to forward events:

1. Install: https://stripe.com/docs/stripe-cli  
2. Log in: `stripe login`
3. Forward webhooks to your dev server:

   ```bash
   stripe listen --forward-to localhost:3000/api/upgrade/webhook
   ```

4. The CLI prints a **webhook signing secret** (e.g. `whsec_...`). Set it in your env:

   ```bash
   export STRIPE_WEBHOOK_SECRET=whsec_...
   ```

   (Or add `STRIPE_WEBHOOK_SECRET=whsec_...` to `dashboard/.env` and restart `npm run dev`.)

5. Run the flow again: **Upgrade** → pay with `4242...` → complete.  
   After checkout, the CLI forwards `checkout.session.completed` to your app; the webhook handler sets `User.subscriptionTier = "paid"` and stores `stripeCustomerId`.

## 4. Test complete-page protection

- Open **http://localhost:3000/upgrade/complete** (no `session_id`). You should be redirected to **/upgrade**.
- Open **http://localhost:3000/upgrade/complete?session_id=invalid**. After verify fails, you should be redirected to **/upgrade**.

## Stripe test cards (reference)

| Card number         | Behavior        |
|---------------------|-----------------|
| 4242 4242 4242 4242 | Success         |
| 4000 0000 0000 0002 | Declined        |
| 4000 0025 0000 3155 | 3DS required    |

More: https://docs.stripe.com/testing#cards
