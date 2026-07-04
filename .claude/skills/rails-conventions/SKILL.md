# Skill: rails-conventions

## Project Structure

```
app/
  controllers/        # Thin. No business logic.
  models/             # Associations, validations, scopes, enums only.
  services/           # All business logic. Plain Ruby objects.
  jobs/               # Sidekiq jobs. One job per pipeline.
  channels/           # ActionCable channels.
  policies/           # Pundit policies.
  views/              # ERB + Turbo Streams. No logic beyond conditionals.
```

## Service Objects

- Location: `app/services/`
- Naming: `NounVerb` or `Noun::Verb` — e.g. `ScrapingService`, `Apps::StoreUrlParser`
- Interface: class methods only for simple cases — `ScrapingService.fetch(...)`
- Return values: plain Ruby objects or hashes. Raise named errors on failure.
- Never call service objects from views or models.

```ruby
# Good
class ScrapingService
  Error = Class.new(StandardError)

  def self.fetch(app_store_id:, play_store_id:, **opts)
    # ...
  end
end

# Bad — logic in controller
def create
  reviews = HTTParty.post(ENV['SCRAPING_SERVICE_URL'], ...)
end
```

## Controllers

- One `before_action :authenticate_user!` in ApplicationController
- One `authorize` call per action (Pundit)
- No instance variables beyond what the view needs
- Respond with Turbo Streams for in-page updates, redirect for full navigations

## Models

- Validations, associations, enums, and named scopes only
- No HTTP calls, no service calls, no file I/O
- Enums always defined with explicit integer mapping:

```ruby
enum status: { pending: 0, fetching: 1, analyzing: 2, complete: 3, failed: 4 }
```

## Rails 8 — Solid Queue Opt-out

Rails 8 defaults to Solid Queue. This project uses Sidekiq instead.
When generating the app or configuring jobs, always explicitly set:

```ruby
# config/application.rb
config.active_job.queue_adapter = :sidekiq
```

And ensure `config/initializers/sidekiq.rb` points to Redis:

```ruby
Sidekiq.configure_server { |c| c.redis = { url: ENV['REDIS_URL'] } }
Sidekiq.configure_client { |c| c.redis = { url: ENV['REDIS_URL'] } }
```

Rails 8 also does not include the `redis` gem by default. It must be added
explicitly to the Gemfile whenever ActionCable or Sidekiq uses Redis:

```ruby
gem 'redis', '~> 5.0'
```

Do not use `solid_queue`, `SolidQueue::Job`, or any Solid Queue configuration.
ActionCable uses the Redis adapter (not Solid Cable).

```yaml
# config/cable.yml
development:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") { "redis://localhost:6379/1" } %>
```

## Environment Variables

- All secrets via `ENV[]` — never hardcoded
- Every env var documented in `.env.example`
- Access pattern: `ENV.fetch('KEY')` in initializers, `ENV['KEY']` elsewhere

## Asset Pipeline

- Never run `rails assets:precompile` in development — Propshaft serves source
  files directly from `app/assets/` and picks up changes on every request
- `public/assets/` must be empty in development — if it exists, precompiled files
  take priority over live source files and CSS changes will not reflect on reload
- If `public/assets/` appears, delete it: `docker compose exec web rm -rf public/assets`
- `public/assets/` is gitignored — never commit precompiled assets

## General Rules

- No logic in views beyond `if/unless` and iteration
- No `binding.pry` or `puts` left in committed code
- Prefer `insert_all` over looping `.create` for bulk inserts
- All DB queries scoped through Pundit policy scopes — never raw `Model.all`
