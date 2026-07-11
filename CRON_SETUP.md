# Cron endpoints

Auth for all cron routes: `Authorization: Bearer <CRON_SECRET>` or query `?secret=<CRON_SECRET>`.

If `CRON_SECRET` is unset, the verifier allows the request (intended for local dev only — **set in production**).

Configure Railway Cron or another scheduler to POST to the deployed API URL with the secret.

## Trial reminders

- Endpoint: `POST /api/v1/cron/trial_reminders`

## Link / campaign milestones (time-based)

- Endpoint: `POST /api/v1/cron/link_milestones`
- Scans links and campaigns with `alert_interval_kind=time` and push or email alerts enabled
- Runs `DeliverMilestoneAlertJob.perform_now` for each due entity (same reliability as click milestones; does not depend on a background job adapter)
- **Production must schedule this cron** (Railway Cron or equivalent) or time-based alerts will never fire
- Response: `{ ok, checked, enqueued }` (`enqueued` = number of due entities processed)
- Recommended schedule: hourly or daily

Example:

```bash
curl -X POST "https://YOUR_API_HOST/api/v1/cron/link_milestones" \
  -H "Authorization: Bearer $CRON_SECRET"
```
