# Permissions

This document describes the Links API authorization model, admin API, and how to extend permissions for new features.

## Two orthogonal axes

| Field | Meaning |
|-------|---------|
| `user.admin` (boolean) | **Platform admin** — access to `/admin` dashboard and admin API |
| `user.role` (`owner` \| `admin` \| `member`) | **Team role** — billing and future team features |

**Important:** `role: "admin"` is a team role, **not** platform admin. UI copy should say "Platform admin" vs "Team role".

## Architecture

```
Permissions::Rules  →  Ability (CanCanCan)
                     →  Permissions::Presenter  →  User#as_json_for_client
```

- **Single source of truth:** `app/models/permissions/rules.rb`
- **Client JSON:** `permissions` + `limits` on every auth/session response
- **Feature flags:** `FeatureFlag` model; toggles affect `Permissions::Presenter`

## Platform admin matrix

| Resource | index | show | create | update | destroy |
|----------|-------|------|--------|--------|---------|
| `User` | yes | yes | no | yes (`admin`, `role`, `subscription_tier`) | no |
| `FeatureFlag` | yes | yes | no | yes (`enabled`) | no |
| `Link` | yes | yes | no | no | yes |
| `Team` | yes (via `:admin_teams`) | yes | no | no | no |
| `Campaign` | yes | — | no | no | yes |
| `Workspace` | yes | — | no | no | yes |
| `CustomDomain` | yes | — | no | no | yes |
| `WebPushSubscription` | yes | — | no | no | yes |

Symbols:

| Symbol | Actions |
|--------|---------|
| `:admin_dashboard` | read |
| `:admin_health` | read |
| `:admin_teams` | read |
| `:admin_billing` | read |
| `:admin_billing_portal` | create |
| `:admin_billing_cancel` | create |

Platform admins **also** receive solo-user rules (own links, billing, etc.).

## Solo user matrix

| Resource / symbol | Actions |
|-------------------|---------|
| `Link` | read/create/update/destroy own; create blocked when `at_link_limit?` |
| `WebPushSubscription` | create/destroy own |
| `User` | read self only |
| `:checkout` | create if `role` is `owner` |
| `:portal` | create if billing allowed + `stripe_customer_id` present |
| `Plan` | read (public) |

## Tier limits

Defined in `User::TIER_LIMITS`. Exposed in client JSON as:

```json
{
  "limits": {
    "links": { "used": 1, "max": 1 },
    "campaigns": { "used": 0, "max": 0 }
  }
}
```

`max: null` means unlimited.

## Feature flags

Seeded keys: `campaigns`, `randomizer`, `web_push`, `workspaces`, `custom_domains`.

When a flag is disabled, related `permissions` booleans are `false` in client JSON.

## Admin API routes

```
GET    /api/v1/admin/dashboard
GET    /api/v1/admin/health
GET    /api/v1/admin/teams
GET    /api/v1/admin/teams/:id
GET    /api/v1/admin/billing/overview
GET    /api/v1/admin/billing/lookup              # ?email=
POST   /api/v1/admin/billing/portal_session    # { user_id }
POST   /api/v1/admin/billing/cancel_subscription  # { user_id, immediate? }
GET    /api/v1/admin/users
GET    /api/v1/admin/users/:id
PATCH  /api/v1/admin/users/:id                 # whitelist: admin, role, subscription_tier
GET    /api/v1/admin/links
GET    /api/v1/admin/links/:id
DELETE /api/v1/admin/links/:id
GET    /api/v1/admin/feature_flags
PATCH  /api/v1/admin/feature_flags/:key        # whitelist: enabled
GET    /api/v1/admin/campaigns
DELETE /api/v1/admin/campaigns/:id
GET    /api/v1/admin/workspaces
DELETE /api/v1/admin/workspaces/:id
GET    /api/v1/admin/custom_domains
DELETE /api/v1/admin/custom_domains/:id
GET    /api/v1/admin/web_push_subscriptions
DELETE /api/v1/admin/web_push_subscriptions/:id
```

Query params: `q`, `page`, `per_page` (max 200), `role`, `user_id` (links), `personal` (teams).

Admin JSON uses camelCase: `linksCount`, `createdAt`, `recentLinks`, `userId`, `userEmail`, `mrrCents`, `recentEvents`.

## Frontend

- `usePermissions()` hook reads `user.permissions` and `user.limits`
- `/admin/*` uses separate `AdminLayout` (not `AppLayout`)
- Admin nav link visible only when `permissions.platformAdmin`
- Non-platform admins see an explicit access-denied state at `/admin/login`

## Extending permissions (Phase 2)

1. Add rules in `Permissions::Rules#apply_to` (or uncomment stubs in `ability_team_roles.rb`)
2. Add presenter booleans in `permissions_hash`
3. Update `UserPermissions` TypeScript type
4. Gate UI with `usePermissions()` or `FeatureGate`
5. Add specs to `ability_spec.rb` and relevant request specs

## Out of scope for CanCanCan

Service auth remains outside Ability: Stripe webhooks, cron, magic-link verify, public signup.
