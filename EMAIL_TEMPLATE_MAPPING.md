# Email templates (design repo → mailers)

Design HTML lives in `links_frontend/email-templates/` (mirrored in `.figma-design-repo/email-templates/`). Brand: **Links** by **BlackCollar**.

## Live mailers (HTML + text)

| Design inspiration | Mailer | When | Status |
|--------------------|--------|------|--------|
| `email-verification.html` (auth CTA) | `UserMailer#magic_link` | Magic link / sign-in | **Live** HTML+text |
| `link-milestone.html` (simplified) | `UserMailer#link_created` | After `create-with-account` | **Live** HTML+text |
| `link-milestone.html` | `UserMailer#link_milestone` | Click milestone alerts | **Live** HTML+text |
| `campaign-summary.html` / milestone | `UserMailer#campaign_milestone` | Campaign click milestones | **Live** HTML+text |
| `team-invitation.html` | `TeamMailer#invitation` | Team invite | **Live** HTML+text |
| Branded shell (light) | `ContactMailer#inbound` | Contact form → ops inbox | **Live** HTML+text |

Shared shell: `app/views/layouts/mailer.html.erb` (logo via `EMAIL_LOGO_URL` / `FRONTEND_ORIGIN` + `/icons/icon.svg`, Montserrat, black CTAs, BlackCollar footer).

Helpers: `MailerHelper` (`frontend_app_url`, `email_logo_url`, dashboard/help/privacy/preferences URLs).

## Design assets only (not wired)

| Design template | Future mailer | Notes |
|-----------------|---------------|--------|
| `welcome-email.html` | (future) | Post sign-up |
| `password-reset.html` | Devise `reset_password_instructions` | When HTML Devise mailer is customized |
| `email-verification.html` | (future confirmable) | Pattern reused by magic_link |
| `weekly-analytics.html` | (future) | No cron send pipeline yet |
| `monthly-report.html` | (future) | No cron send pipeline yet |
| `domain-verification.html` | (future) | Custom domain flow email |
| `link-limit-warning.html` | (future) | Plan limit warnings |
| `upgrade-confirmation.html` | (future) | Billing upgrade |
| `inactive-user-reengagement.html` | (future) | Reengagement |
| `campaign-summary.html` | (future full report) | Milestone uses a slim variant today |

Do **not** wire weekly/welcome/etc. send jobs until those features ship.
