---
paths:
  - "app/**/*.rb"
  - "lib/**/*.rb"
  - "config/**/*.rb"
  - "db/**/*.rb"
---

# Rails conventions

## Where code goes

- Controllers are thin: authenticate, authorize, call a service, respond.
- Models hold associations, validations, enums, and scopes. Nothing else:
  no HTTP calls, no service calls, no file I/O.
- All business logic lives in `app/services/` as plain Ruby objects.
- One Sidekiq job per pipeline.

## Services

- Namespaced by area when there is one: `Apps::StoreUrlParser`,
  `Workspaces::InviteMemberService`, `ScrapingService`.
  Follow the naming of the neighbours in the folder you are adding to.
- Return plain Ruby objects or hashes. Raise named errors on failure
  (`Error = Class.new(StandardError)` on the service).
- Never called from views or models.

## Models

- Enums use the Rails 8 form with explicit integers:
  `enum :status, { pending: 0, fetching: 1 }`.
- `db/schema.rb` is the source of truth for columns. Read it; don't assume.

## Jobs and real-time

Sidekiq, not Solid Queue: `config.active_job.queue_adapter = :sidekiq` in
`config/application.rb`. Never add `solid_queue` or Solid Queue config.
ActionCable uses the Redis adapter, not Solid Cable.

## Data access

Bulk inserts use `insert_all` / `upsert_all`, not a loop of `.create`.