---
paths:
  - "app/**/*.rb"
  - "lib/**/*.rb"
  - "config/**/*.rb"
  - "db/**/*.rb"
---

# Rails conventions

## Where code goes

```
app/
  controllers/   # Thin: authenticate, authorize, call a service, respond.
  models/        # Associations, validations, enums, scopes. Nothing else.
  services/      # All business logic. Plain Ruby objects.
  jobs/          # Sidekiq jobs. One job per pipeline.
  channels/      # ActionCable channels.
  policies/      # Pundit policies.
  views/         # ERB + Turbo Streams. No logic beyond if/unless and iteration.
```

## Services

- Live in `app/services/`, namespaced by area when there is one —
  `Apps::StoreUrlParser`, `Workspaces::InviteMemberService`, `ScrapingService`.
  Follow the naming of the neighbours in the folder you are adding to.
- Return plain Ruby objects or hashes. Raise named errors on failure
  (`Error = Class.new(StandardError)` on the service).
- Never called from views or models.

## Models

- No HTTP calls, no service calls, no file I/O.
- Enums use the Rails 8 form with explicit integers:
  `enum :status, { pending: 0, fetching: 1 }`.
- `db/schema.rb` is the source of truth for columns. Read it — don't assume.

## Jobs

Sidekiq, not Solid Queue — `config.active_job.queue_adapter = :sidekiq` in
`config/application.rb`. Never add `solid_queue` or Solid Queue config.
ActionCable uses the Redis adapter, not Solid Cable.

## Data access

- Bulk inserts use `insert_all` / `upsert_all`, not a loop of `.create`.
- Queries on workspace content go through a Pundit policy scope, never a bare `Model.all`.

## Environment variables

Every new variable goes into `.env.example`.

## Before committing

No `binding.pry`, `debugger`, or `puts` left in the code.
