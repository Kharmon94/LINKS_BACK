# Stripe setup

## Pro plan ($50/mo or $500/yr)

1. Create **Links Pro** product and prices in Stripe Dashboard (test and live), or use Stripe MCP.
2. Set price ID env vars on the API service:

| Variable | Mode |
|----------|------|
| `STRIPE_PRICE_PRO_MONTHLY` | Test monthly |
| `STRIPE_PRICE_PRO_YEARLY` | Test yearly |
| `STRIPE_PRICE_PRO_MONTHLY_LIVE` | Live monthly |
| `STRIPE_PRICE_PRO_YEARLY_LIVE` | Live yearly |

3. Run `rails db:seed` to bind price IDs to the Pro plan (`monthly_amount_cents: 5000`). Legacy starter/growth plan rows are deactivated but remain for webhook price mapping.

## Keys and webhooks

1. Set `STRIPE_SECRET_KEY` (test) and `STRIPE_SECRET_KEY_LIVE` (live).
2. Register webhook endpoint `POST /api/v1/webhooks/stripe` in **both** Stripe test and live dashboards:

   `https://api.blackcollar.io/api/v1/webhooks/stripe`

3. Set `STRIPE_WEBHOOK_SECRET` and `STRIPE_WEBHOOK_SECRET_LIVE` from each endpoint's signing secret.
4. Webhooks accept events from **either** test or live (dual-secret verification). Checkout/portal use the admin **Stripe mode** toggle (database) with `STRIPE_LIVE_MODE` env as fallback.

## Sync task

`rails stripe:sync_plans` skips plans that already have price IDs for the current mode. If it creates prices, it uses $50/mo and $500/yr (not legacy $10).

## Development

- Use **test** keys in development.
- Checkout success/cancel URLs use `FRONTEND_ORIGIN`.
- Webhook handlers resolve subscription IDs from invoices via `SubscriptionIdFromInvoice`.
- Always pass Stripe `api_key` in the **third** argument (opts), never merged into request params.
