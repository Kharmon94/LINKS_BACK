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
| `API_HOST` | Optional | API deployment host (e.g. `api.blackcollar.io`). No longer required for redirects: any host that is not a registered custom domain resolves platform short links. Still useful for documentation and future host-specific behavior. |
| `VITE_CUSTOM_DOMAIN_CNAME_TARGET` | Frontend build | Shared DNS CNAME target shown in Settings → Domains Step 2b (defaults from `VITE_API_URL` host). |
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

Short URLs must reach **Rails** `GET /:short_code` (`RedirectsController`), not the React SPA alone.

| Setup | What to do |
|-------|------------|
| **Recommended** | Point `SHORT_LINK_HOST` (e.g. `links.blackcollar.io`) at the **API** Railway service. Serve the dashboard SPA on a separate host (e.g. `app.blackcollar.io`). |
| **Shared host (current)** | `links.blackcollar.io` runs a small **Node proxy** (`server.mjs`) on the frontend Railway service. It matches `GET`/`HEAD /:shortCode`, server-side `fetch`es the API, and forwards `302` + `Location` to the browser. The visitor never navigates to `api.blackcollar.io`. All other paths serve the SPA build. |

**Frontend service env (server-only, not `VITE_*`):**

| Variable | Notes |
|----------|--------|
| `API_URL` | API origin for the short-link proxy, e.g. `https://api.blackcollar.io` (no trailing slash). |
| `PORT` | Set by Railway; the proxy listens here. |

The proxy forwards `X-Forwarded-For`, `X-Forwarded-Host` (original `Host`, e.g. `links.blackcollar.io`), `User-Agent`, and `Referer` from the browser to the API so redirects resolve the platform namespace and click analytics use the visitor IP. The API trusts Railway/private proxy ranges in production (`config.action_dispatch.trusted_proxies`).

`VITE_API_URL` remains required at **frontend build time** for SPA calls to `/api/v1/...`; only the short-link path uses `API_URL` at runtime.

Ensure `VITE_API_URL` on the frontend build matches the live API (with `https://`, no trailing slash).

**Data repair (one-time after deploy):** if links were created before the customize fix and have `custom_domain_id` set incorrectly, run on the API service:

```bash
bundle exec rake links:repair_platform_short_urls          # dry-run report
bundle exec rake links:repair_platform_short_urls DRY_RUN=false
bundle exec rake links:repair_platform_short_urls LINK_IDS=4 DRY_RUN=false  # single link
```

### Custom domains (API-direct routing)

Customer branded domains must hit the **API** service (`RedirectsController`), not the React SPA.

1. **Enable flag** — `bundle exec rails db:seed` (or Admin → Feature Flags → `custom_domains`).
2. **Tier** — billing account (team owner) on `growth` (10 domains) or `enterprise` (unlimited).
3. **TXT verify** — customer adds `_links-verification.{domain}` TXT and clicks Verify in Settings.
4. **Railway TLS (per customer)** — after TXT verify, add `{domain}` to **API service** → Networking → Custom Domain.
5. **Customer DNS** — customer adds the record Railway shows (often CNAME → `{service}.up.railway.app`) or your shared target from `CUSTOM_DOMAIN_CNAME_TARGET` / `VITE_CUSTOM_DOMAIN_CNAME_TARGET`.
6. **Env on API service:**
   - `SHORT_LINK_HOST=links.blackcollar.io` (platform short links — also a Railway custom domain on API service)
   - `API_HOST=api.blackcollar.io` (optional; platform redirects work on any non-custom-domain host)
7. **Env on frontend build:**
   - `VITE_CUSTOM_DOMAIN_CNAME_TARGET` — shared DNS target shown in Settings step 2b

**Important:** `api.blackcollar.io` is your platform API hostname. Customer domains still need individual Railway registration for TLS; their DNS may CNAME to the Railway service hostname, not necessarily to `api.blackcollar.io`.

Redirect isolation: verified custom hosts resolve only links on that domain; pending custom hosts return 404 (no platform fallback). All other hosts (including `api.blackcollar.io` when proxied) resolve platform short links via `find_platform_link`.

### Feature flags (`db:seed`)

`bundle exec rails db:seed` ensures feature flags exist. The **`campaigns`**, **`workspaces`**, and **`custom_domains`** flags are always set to **enabled** on seed (safe to re-run). If `/api/v1/campaigns` returns 403, run seed on the API service or enable campaigns in Admin → Feature Flags. If `/api/v1/team` or workspaces APIs return 403, run seed or enable **workspaces** in Admin → Feature Flags.

| `VAPID_PUBLIC_KEY` / `VAPID_PRIVATE_KEY` | Push | Web Push VAPID keys |
| `VAPID_SUBJECT` | Push | Contact for push service, e.g. `mailto:support@...` |

See [.env.example](.env.example) for a copy-paste template.
