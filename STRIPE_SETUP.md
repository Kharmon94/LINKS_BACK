# Stripe setup

1. Create Products/Prices in Stripe Dashboard **or** run `rails stripe:sync_plans` when `STRIPE_SECRET_KEY` is set (entrypoint runs this on server boot when the key exists).
2. Set `STRIPE_WEBHOOK_SECRET` from the webhook signing secret for endpoint `POST /api/v1/webhooks/stripe`.
3. Use **test** keys in development; set `STRIPE_LIVE_MODE=1` and live keys only when going live.
4. Checkout success/cancel URLs are configured in `Api::V1::CheckoutController` using `FRONTEND_ORIGIN`.
5. Webhook handlers resolve subscription IDs from invoices via `SubscriptionIdFromInvoice` to tolerate Stripe API shape differences.
6. Always pass Stripe `api_key` in the **third** argument (opts), never merged into request params.
