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
| `API_HOST` | Optional | API deployment host (e.g. `links-api-production.up.railway.app`). Skips custom-domain lookup on redirect for faster default short links. |
| `REDIRECT_ASYNC_CLICKS` | Optional | Set to `true` to record clicks in a background job so the 302 returns sooner. Requires Solid Queue (`SOLID_QUEUE_IN_PUMA=true`) or clicks may not persist. |
| `SOLID_QUEUE_IN_PUMA` | Optional | Run `true` on single-server Railway deploys so background jobs (e.g. async click recording) process. |
| `GEOIP_DB_PATH` | Optional | Path to MaxMind **GeoLite2-City** `.mmdb` for click geo fallback (see below) |
| `REDIRECT_ALLOWED_HOSTS` | Optional | Comma-separated extra hosts allowed for redirects (usually unnecessary after host-relaxation) |

### GeoIP (click analytics)

Redirect clicks resolve country/city in this order:

1. **CDN headers** (no lookup): `CF-IPCountry`, `CloudFront-Viewer-Country`, `X-Vercel-IP-Country` — ISO codes are mapped to full country names automatically
2. **Local GeoLite2** via the `geocoder` gem when `GEOIP_DB_PATH` points to a valid `.mmdb` file (default: `vendor/GeoLite2-City.mmdb`)

If the API sits behind **Cloudflare**, enable IP Geolocation on the zone (or ensure `CF-IPCountry` is passed through to the origin). Without CDN headers or a local MMDB, country/city stay `nil` but redirects still work.

Download GeoLite2-City from a free [MaxMind account](https://www.maxmind.com/en/geolite2/signup), place the MMDB on the API service, and set `GEOIP_DB_PATH`. Update the database periodically.

Run `bundle exec rake analytics:reconcile_clicks` once after deploy if `links.clicks_count` may drift from `click_events`.

### Short link routing (production)

Short URLs must hit **Rails** `GET /:short_code` (`RedirectsController`), not the React SPA.

| Setup | What to do |
|-------|------------|
| **Recommended** | Point `SHORT_LINK_HOST` (e.g. `links.blackcollar.io`) at the **API** Railway service. Serve the dashboard SPA on a separate host (e.g. `app.blackcollar.io`). |
| **Shared host** | If `links.blackcollar.io` serves the **frontend**, set `VITE_API_URL` to your API URL at frontend build time. A lightweight inline script in `index.html` forwards `/:short_code` to the API **before** React loads (no 1MB bundle wait). |

Ensure `VITE_API_URL` on the frontend build matches the live API (with `https://`, no trailing slash).
| `VAPID_PUBLIC_KEY` / `VAPID_PRIVATE_KEY` | Push | Web Push VAPID keys |
| `VAPID_SUBJECT` | Push | Contact for push service, e.g. `mailto:support@...` |

See [.env.example](.env.example) for a copy-paste template.
