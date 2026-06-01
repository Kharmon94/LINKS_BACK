# Environment variables — `links_api`

| Variable | Required | Notes |
|----------|----------|--------|
| `SECRET_KEY_BASE` / `RAILS_MASTER_KEY` | Production | Rails secret |
| `DEVISE_JWT_SECRET_KEY` | Recommended | JWT signing; defaults to `secret_key_base` if unset |
| `FRONTEND_ORIGIN` | Production | CORS + OAuth redirect + mailer links |
| `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` | For Google sign-in | OAuth client |
| `ADMIN_SEED_EMAIL` / `ADMIN_SEED_PASSWORD` | Optional deploy | Seeds first admin |
| `DATABASE_URL` | Production (Postgres) | When unset, production falls back to SQLite files |
| `RESEND_API_KEY` | Production email | Used as SMTP password |
| `RESEND_SMTP_PORT` | Optional | Defaults to `465` |
| `RESEND_SMTP_USERNAME` | Optional | Defaults to `resend` |
| `APP_HOST` or `MAILER_HOST` | Production email | `default_url_options` host |
| `STRIPE_*` | Billing | See [STRIPE_SETUP.md](STRIPE_SETUP.md) |
| `CRON_SECRET` | Cron endpoints | Bearer or `?secret=` |
| `AWS_*` | S3 uploads | When all set, Active Storage uses `:amazon` |
| `SHORT_LINK_HOST` | Optional | Host prefix in link JSON (no scheme) |
| `VAPID_PUBLIC_KEY` / `VAPID_PRIVATE_KEY` | Push | Web Push VAPID keys |
| `VAPID_SUBJECT` | Push | Contact for push service, e.g. `mailto:support@...` |

See [.env.example](.env.example) for a copy-paste template.
