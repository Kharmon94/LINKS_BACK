# Environment variables — `links_api`

| Variable | Required | Notes |
|----------|----------|--------|
| `SECRET_KEY_BASE` / `RAILS_MASTER_KEY` | Production | Rails secret |
| `DEVISE_JWT_SECRET_KEY` | Recommended | JWT signing; defaults to `secret_key_base` if unset |
| `FRONTEND_ORIGIN` | Production | CORS + OAuth redirect + mailer links |
| `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` | For Google sign-in | OAuth client |
| `ADMIN_SEED_EMAIL` / `ADMIN_SEED_PASSWORD` | Optional deploy | `db:seed` ensures admin only when both are set |
| `STRIPE_PRICE_STARTER_MONTHLY` / `YEARLY` (+ `_LIVE`) | Billing | `db:seed` ensures Starter plan only when set (no placeholder IDs) |
| `DATABASE_URL` | Production (Postgres) | When unset, production falls back to SQLite files |
| `RESEND_API_KEY` | Production email | Used as SMTP password |
| `RESEND_SMTP_PORT` | Optional | Defaults to `465` |
| `RESEND_SMTP_USERNAME` | Optional | Defaults to `resend` |
| `APP_HOST` or `MAILER_HOST` | Production email | `default_url_options` host |
| `STRIPE_*` | Billing | See [STRIPE_SETUP.md](STRIPE_SETUP.md) |
| `CRON_SECRET` | Cron endpoints | Bearer or `?secret=` |
| `AWS_*` | S3 uploads | When all set, Active Storage uses `:amazon` |
| `SHORT_LINK_HOST` | Optional | Host shown in link JSON (no scheme), e.g. `links.blackcollar.io` |
| `REDIRECT_ALLOWED_HOSTS` | Optional | Comma-separated extra hosts allowed for redirects (usually unnecessary after host-relaxation) |

### Short link routing (production)

Short URLs must hit **Rails** `GET /:short_code` (`RedirectsController`), not the React SPA.

| Setup | What to do |
|-------|------------|
| **Recommended** | Point `SHORT_LINK_HOST` (e.g. `links.blackcollar.io`) at the **API** Railway service. Serve the dashboard SPA on a separate host (e.g. `app.blackcollar.io`). |
| **Shared host** | If `links.blackcollar.io` serves the **frontend**, set `VITE_API_URL` to your API URL at frontend build time. The SPA forwards `/:short_code` to the API before redirecting to the destination. |

Ensure `VITE_API_URL` on the frontend build matches the live API (with `https://`, no trailing slash).
| `VAPID_PUBLIC_KEY` / `VAPID_PRIVATE_KEY` | Push | Web Push VAPID keys |
| `VAPID_SUBJECT` | Push | Contact for push service, e.g. `mailto:support@...` |

See [.env.example](.env.example) for a copy-paste template.
