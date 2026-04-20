# Email templates (design repo → mailers)

Design HTML lives in the design repo under `email-templates/`. Rails transactional mailers in this API:

| Design template | Mailer | When |
|-----------------|--------|------|
| `password-reset.html` | Devise `reset_password_instructions` | Password reset flow |
| `welcome-email.html` | (future) | Post sign-up |
| `email-verification.html` | (future) | Confirmable, if enabled |
| `link-milestone.html` / link created copy | `UserMailer#link_created` | After `create-with-account` |
| Magic link copy | `UserMailer#magic_link` | After `magic-link` request or onboarding |

Implement HTML versions in `app/views/user_mailer/` when parity with design is required; current API uses **text** templates for minimal setup.
