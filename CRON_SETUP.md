# Cron (trial reminders)

- Endpoint: `POST /api/v1/cron/trial_reminders`
- Auth: `Authorization: Bearer <CRON_SECRET>` or query `?secret=<CRON_SECRET>`
- If `CRON_SECRET` is unset, the verifier allows the request (intended for local dev only — **set in production**).

Configure Railway Cron or another scheduler to POST to the deployed API URL with the secret.
