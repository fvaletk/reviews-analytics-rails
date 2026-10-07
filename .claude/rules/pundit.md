---
paths:
  - "app/policies/**/*.rb"
  - "app/controllers/**/*.rb"
  - "spec/policies/**/*.rb"
---

# Authorization (Pundit)

Roles live on `WorkspaceMembership`, never on `User` — a role is always workspace-scoped.

```
collaborator  → view only
admin         → view + generate reports
super_admin   → view + generate + invite/remove members
```

## Rules

- One policy per model in `app/policies/`. `app/policies/workspace_policy.rb` is the reference shape.
- Every controller action calls `authorize`. `ApplicationController` enforces it with
  `after_action :verify_authorized` (Devise controllers are skipped).
- Every index action uses `policy_scope(Model)`. **This is not enforced** — there is no
  `verify_policy_scoped` — so it is on you.
- No role checks in controllers or views. Ask the policy: `policy(@workspace).invite?`.
- `ApplicationController#membership_in(workspace)` returns the current user's membership or nil.
- `Pundit::NotAuthorizedError` already renders 404 from `ApplicationController` — never 403,
  so unauthorized users can't confirm a resource exists. Don't add per-controller rescues unless
  a ticket requires a different status. (`ReportsController` returns 403 for all its actions.)
