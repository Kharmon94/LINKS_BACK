# Permissions

This document describes the Links API authorization model, admin API, and how to extend permissions for new features.

## Two orthogonal axes

| Field | Meaning |
|-------|---------|
| `user.admin` (boolean) | **Platform admin** — access to `/admin` dashboard and admin API |
| `user.role` (`owner` \| `admin` \| `member`) | **Legacy team role on `users` table** — kept in sync with personal-team `TeamMembership` |
| `TeamMembership.role` | **Authoritative team role** when workspaces are enabled (`user.team_role` reads this first) |

**Important:** `role: "admin"` is a team role, **not** platform admin. UI copy should say "Platform admin" vs "Team role".

## Architecture

```
Permissions::Rules  →  Ability (CanCanCan)
                     →  Permissions::Presenter  →  User#as_json_for_client
```

- **Single source of truth:** [`app/models/permissions/rules.rb`](app/models/permissions/rules.rb)
- **Client JSON:** `permissions` + `limits` on every auth/session response
- **Feature flags:** `FeatureFlag` model gates collaboration features in both Ability and Presenter

### Rule application order

1. **Solo user rules** — own links (when workspaces off), web push, self user profile, checkout/portal, plans
2. **Collaboration rules** — workspaces, campaigns, team, custom domains, analytics (feature-flag gated)
3. **Platform admin rules** — when `user.admin?` (additive; admins also retain solo-user abilities on own resources)

## Feature flags

| Key | Gates |
|-----|--------|
| `campaigns` | Campaign CRUD + assign/unassign links |
| `workspaces` | Workspaces, team API, workspace-scoped links/campaigns |
| `randomizer` | Link type in controller (not CanCanCan) |
| `custom_domains` | Custom domain CRUD (also requires growth/enterprise tier) |
| `web_push` | Web push subscription create/destroy |

When a flag is disabled, related `permissions` booleans are `false` in client JSON and Ability rules are not applied.

## Solo user matrix

### Links

| Mode | Rules |
|------|-------|
| Workspaces **off** | `show`/`update`/`destroy` own links (`user_id`); `create` unless `at_link_limit?` |
| Workspaces **on** | Solo link rules skipped; workspace-scoped link rules apply (see below) |

### Campaigns (`campaigns` flag)

| Role | read | create | update | destroy | assign_links |
|------|------|--------|--------|---------|--------------|
| owner/admin | yes (own or workspace-scoped) | yes unless `at_campaign_limit?` | yes | yes | yes |
| member | yes (read only) | no | no | no | no |

Scope: `user_id` when workspaces off; `workspace_id` in accessible workspaces when workspaces on.

### Workspaces (`workspaces` flag)

Accessible workspaces = any workspace the user has a `WorkspaceMembership` on (not limited to personal team).

| Role on team | read | create | update | destroy |
|--------------|------|--------|--------|---------|
| owner | member workspaces | yes (teams where owner) | yes (teams where owner/admin) | yes (teams where owner) |
| admin | member workspaces | yes (teams where admin) | yes (teams where admin) | no |
| member | member workspaces | no | no | no |

### Team (`workspaces` flag)

| Symbol / resource | owner | admin | member |
|-------------------|-------|-------|--------|
| `:team` read | yes | yes | yes |
| `TeamInvitation` create | yes | yes | no |
| `TeamInvitation` accept | yes (any user with account) | yes | yes |
| `TeamMembership` read | yes | yes | yes |
| `TeamMembership` update | yes | no | no |
| `TeamMembership` destroy | yes | yes | no |

Presenter mapping: `team.invite` = owner/admin; `team.manage` = owner only.

### Custom domains (`custom_domains` flag + growth/enterprise tier)

| Action | owner/admin on allowed tier |
|--------|----------------------------|
| create / update / destroy | own domains only |

### Other solo resources

| Resource / symbol | Actions |
|-------------------|---------|
| `WebPushSubscription` | create/destroy own (when `web_push` flag on) |
| `User` | show/update self |
| `:checkout` | create if `team_role` is `owner` |
| `:portal` | create if billing allowed + `stripe_customer_id` present |
| `Plan` | read (public) |
| `:analytics` | read (always) |

## Platform admin matrix

| Resource | index | show | create | update | destroy |
|----------|-------|------|--------|--------|---------|
| `User` | yes | yes | no | yes (`admin`, `role`, `subscription_tier`) | no |
| `FeatureFlag` | yes | yes | no | yes (`enabled`) | no |
| `Link` | yes | yes | no | **no** | yes |
| `WebPushSubscription` | yes | — | no | no | yes |
| `Campaign` | via `:admin_campaigns` | — | no | no | yes |
| `Workspace` | via `:admin_workspaces` | — | no | no | yes |
| `CustomDomain` | via `:admin_custom_domains` | — | no | no | yes |

### Admin symbols

| Symbol | Actions |
|--------|---------|
| `:admin_dashboard` | read |
| `:admin_health` | read |
| `:admin_teams` | read |
| `:admin_billing` | read |
| `:admin_billing_portal` | create |
| `:admin_billing_cancel` | create |
| `:admin_campaigns` | read, destroy |
| `:admin_workspaces` | read, destroy |
| `:admin_custom_domains` | read, destroy |
| `:admin_web_push` | read, destroy |

Platform admins **also** receive solo-user + collaboration rules (own links, billing, etc.).

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

`max: null` means unlimited. `campaigns.used` counts the user's campaigns.

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

## Frontend

- `usePermissions()` hook reads `user.permissions` and `user.limits`
- `/admin/*` uses separate `AdminLayout` (not `AppLayout`)
- Admin nav link visible only when `permissions.platformAdmin`
- Non-platform admins see an explicit access-denied state at `/admin/*`

## Extending permissions

1. Add rules in `Permissions::Rules` (`apply_solo_user_rules`, `apply_collaboration_rules`, or `apply_platform_admin_rules`)
2. Add presenter booleans in `permissions_hash` if the client needs them
3. Update `UserPermissions` TypeScript type in `links_frontend/src/types/index.ts`
4. Gate UI with `usePermissions()` or `FeatureGate`
5. Add specs to `spec/models/ability_spec.rb` and relevant request specs
6. Update this document

## Out of scope for CanCanCan

Service auth remains outside Ability: Stripe webhooks, cron, magic-link verify, public signup, redirect clicks, `GET /up`.
