# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Reviews Analytics — Rails App

SaaS that fetches App Store and Play Store reviews and generates structured
competitive intelligence reports using Gemini.

**Stack:** Rails 8 · PostgreSQL · Redis · Sidekiq · Hotwire (Turbo + Stimulus) · Pundit · Docker  
**Ruby:** 3.2.5 · **Assets:** Propshaft + Importmap (no Webpack/Vite)

---

## Common Commands

```bash
# Start the server
bin/rails server

# Run all tests
bundle exec rspec

# Run a single spec file
bundle exec rspec spec/models/user_spec.rb

# Run a single example by line
bundle exec rspec spec/models/user_spec.rb:42

# Lint
bin/rubocop

# Security scan
bin/brakeman

# DB tasks
bin/rails db:create db:migrate db:seed
```

---

## Architecture

### Request Lifecycle

```
Request → ApplicationController (authenticate_user!, authorize via Pundit)
        → Thin controller → Service object (app/services/)
        → Respond: redirect | Turbo Stream | JSON
```

Business logic lives exclusively in `app/services/`. Controllers are thin: authenticate, authorize, call a service, respond. Models hold only validations, associations, enums, and scopes.

### Background Jobs

This project uses **Sidekiq** (not Solid Queue). Jobs live in `app/jobs/`. Each job represents one pipeline stage. Real-time UI updates are pushed from jobs via `Turbo::StreamsChannel.broadcast_replace_to`.

### Report Pipeline

Three modes — all create a **new** `Report` record (old reports are never overwritten):

| Mode | Scraping | LLM |
|---|---|---|
| Generate (first time) | ✅ FastAPI call | ✅ |
| Refresh + re-analyze | ✅ FastAPI call | ✅ |
| Re-analyze only | ❌ uses stored reviews | ✅ |

LLM output is validated by `ReportSchemaValidator` before being saved to `reports.structured_output` (JSONB). Never save unvalidated LLM output.

### Authorization

Pundit policies in `app/policies/`. Roles (`collaborator`, `admin`, `super_admin`) live on `WorkspaceMembership`, never on `User`. `NotAuthorizedError` renders 404 — never 403.

### Domain Model

```
User
  └── WorkspaceMemberships (role: super_admin | admin | collaborator)
        └── Workspace
              └── Apps
                    ├── Reviews   (raw, deduplicated by external_id)
                    └── Reports   (versioned JSONB output)

Notifications (belongs to User + Report)
```

Content (Apps, Reviews, Reports) belongs to the **Workspace**, not the creating user.

---

## Design System

Design doc: `DESIGN.md`. Key rules for any view work:

- Dark mode is primary (`data-theme="dark"` on `<html>`). Both themes must work.
- **Never** use hardcoded color values — use CSS variables only (`var(--accent)`, etc.)
- Tailwind is allowed for spacing, flex, grid, and layout utilities **only** — not for colors
- Severity badges always use `var(--font-mono)` — never body font
- Accent color (`--accent`) is amber — never use for destructive actions (use `var(--critical)`)
- Primary button CTAs use uppercase tracking, never sentence case
- No drop shadows in dark mode — use borders and background elevation instead
- Always import the Google Fonts link tag in `application.html.erb`

---

## /work-next-ticket

Run this command to work on the next ticket. Follow each step exactly.

1. Fetch the next **Todo** ticket from Linear project `reviews-analytics-app` (team: Brain Spark)
2. Read the full ticket — title, description, and acceptance criteria
3. **If anything is ambiguous or missing context: STOP. Ask the user. Do not guess.**
4. Mark ticket **In Progress**
5. Spawn **Sub-agent 1 — Implement**
   - Load relevant skills before writing any code (see Skills section below)
   - Implement exactly what the acceptance criteria describe, nothing more
6. Spawn **Sub-agent 2 — Test**
   - Load `rspec-patterns` skill
   - Write RSpec specs. Do not modify implementation files.
7. Spawn **Sub-agent 3 — Commit**
   - Run `bundle exec rspec` — if any test fails, stop and report back
   - Commit all changes: `git add -A && git commit -m "[BRA-XX] <ticket title>"`
   - Push to `staging` branch: `git push origin staging`
8. Mark ticket **Done** in Linear
9. Loop — fetch next ticket

## Sub-agent Rules

- Each sub-agent starts fresh. Pass all needed context explicitly.
- Sessions are workers, not storage. Nothing important lives in a session.
- Sub-agent 3 never pushes if tests are failing.
- Never create a PR. Push directly to `staging`.

---

## Skills

Load by name before writing code. Match to the work at hand.

| Skill | Load when... |
|---|---|
| `rails-conventions` | any Rails file |
| `rspec-patterns` | writing tests |
| `turbo-patterns` | views, broadcasts, Stimulus |
| `pundit-patterns` | policies, authorization |
| `domain-model` | touching any model or migration |
| `report-schema` | anything touching LLM output or reports |
| `design-system` | any view, layout, or UI component |

Skills live in `.claude/skills/`.
