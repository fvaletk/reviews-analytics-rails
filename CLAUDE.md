# Reviewly — Rails App

SaaS that fetches App Store and Play Store reviews and generates structured
competitive intelligence reports with an LLM (Gemini, behind `LlmService`).

**Stack:** Rails 8 · PostgreSQL · Redis · Sidekiq · Hotwire (Turbo + Stimulus) · Pundit ·
Propshaft + Importmap · Docker. Ruby version: `.ruby-version`.

---

## Project knowledge lives in the Obsidian vault

```yaml
vault_project: reviewly
vault_path: ~/Projects/Capri/01-projects/reviewly
```

Both repos map to this one project folder; the repo name doesn't match it.

- **Run `/project-context` at the start of a session.** It reads the folder in order and
  reports what's unfinished, the current status, and open findings.
- **Read `analysis/current-understanding.md` before deciding anything about the LLM
  pipeline, review sampling, or cost.** It records what's already settled and why.
- **The vault can be stale; this repo is the truth.** Verify paths and line numbers in the code.
- **Found an unrelated bug mid-task?** Run `/report-issue` (no arguments). It writes a finding
  to the vault without creating a ticket or touching code. Don't fix it in the current ticket.

---

## Running things

Everything runs inside Docker. Start it with `docker compose up -d`. The repo is mounted
at `/rails`, so files written locally appear in the container instantly — never use
`docker compose cp`.

```bash
docker compose exec web bundle exec rspec                              # all specs
docker compose exec web bundle exec rspec spec/models/user_spec.rb:42  # one example
docker compose exec web bin/rubocop                                    # lint
docker compose exec web bin/brakeman                                   # security scan
docker compose exec web bin/rails db:migrate
```

Services: `web`, `sidekiq`, `db`, `redis`. Tests are RSpec only — there is no Minitest.

---

## Architecture

```
Request → controller (authenticate_user!, Pundit authorize) → service in app/services/ → redirect | Turbo Stream
```

```
User
  └── WorkspaceMemberships (role: super_admin | admin | collaborator)
        └── Workspace
              └── Apps
                    ├── Reviews   (deduplicated by app + store + external_id)
                    └── Reports   (one per run; LLM output in structured_output JSONB)

Notifications (belong to User + Report)
```

Content belongs to the **Workspace**, not to the user who created it. Removing a member
never removes data.

**Report runs** (`ReportJob`, Sidekiq) — every run creates a new `Report`; old ones are
never overwritten:

| `report_type` | Scrapes via FastAPI | Calls the LLM |
|---|---|---|
| `generate` | ✅ | ✅ |
| `refresh` | ✅ | ✅ |
| `reanalyze` | ❌ uses stored reviews | ✅ |

ICP extraction runs separately in `IcpExtractionJob`. Job progress reaches the UI through
Turbo Stream broadcasts.

Design system: `DESIGN.md`.

---

## Rules

Conventions live in `.claude/rules/`. Each file is scoped by `paths:` and loads when you
work on matching files.

| Rule | Covers |
|---|---|
| `rails.md` | Ruby under `app/`, `lib/`, `config/`, `db/` |
| `pundit.md` | policies, controllers |
| `turbo.md` | views, JS, jobs, channels, controllers |
| `design-system.md` | views, stylesheets, Stimulus — on top of `DESIGN.md` |
| `llm-pipeline.md` | LLM service, prompt builders, validators, report jobs |
| `scrape-contract.md` | `ScrapingService` — the FastAPI contract |
| `rspec.md` | `spec/` |

---

## Tickets

Tickets are worked with `/work-next-ticket` — the steps live in
`.claude/commands/work-next-ticket.md`. Whoever is working, these always hold:

- One branch per ticket, named the ticket's `gitBranchName`, cut from the latest `staging`.
- **Never push to `staging` or `main`.** Every ticket goes through a pull request into
  `staging`. (Human review gate since 2026-10-06.)
- Never merge a PR and never mark a ticket Done — both are the user's.
- Never commit or push with failing specs.

---

## Credentials

- Every environment variable is listed in `.env.example`. Read config with `ENV.fetch("KEY")`.
- **Never read or write `.env`, and never generate credential values.** The developer manages
  it by hand. If a variable is missing, say which one and stop.
- `.claude/hooks/block-sensitive-files.sh` blocks Read/Edit/Write on `.env` files
  (`.env.example` stays readable).
