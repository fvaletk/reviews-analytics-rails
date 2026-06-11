# /docker-check

Verifies the Docker environment is healthy and fixes common issues before
working on tickets. Run this any time the containers behave unexpectedly or
after adding new gems, migrations, or pulling changes from the remote.

## When to Run

- Before starting a new work session
- After pulling changes from the `staging` branch
- After a gem is added to `Gemfile`
- After a new migration is created
- When the `web` container crashes or won't start
- When you see `GemNotFound`, `PG::ConnectionBad`, or `Migrations pending` errors

## What This Command Does

Work through each check in order. Fix any failure before moving to the next.

---

### Step 1 — Verify containers are running

```bash
docker compose ps
```

Expected: `web`, `db`, `redis`, and `sidekiq` all show status `running`.

If any container is not running:
```bash
docker compose up -d
```

Wait 5 seconds, then re-check. If a container keeps restarting, check its logs:
```bash
docker compose logs web --tail=50
docker compose logs db --tail=50
```

Report the log output and stop — do not proceed if `web` or `db` won't start.

---

### Step 2 — Verify gems are installed

```bash
docker compose exec web bundle check
```

If any gems are missing:
```bash
docker compose exec web bundle install
```

If `bundle install` fails, report the full error output and stop.

---

### Step 3 — Verify database connection

```bash
docker compose exec web rails db:version
```

Expected: prints the current schema version number.

If it fails with a connection error:
- Confirm the `db` container is running (Step 1)
- Confirm `DATABASE_URL` is set in `.env`
- Try: `docker compose restart db` then retry

---

### Step 4 — Check for pending migrations

```bash
docker compose exec web rails db:migrate:status
```

If any migrations show `down`:
```bash
docker compose exec web rails db:migrate
```

Re-run `db:migrate:status` to confirm all migrations are `up`.

---

### Step 5 — Verify Sidekiq can connect to Redis

```bash
docker compose exec sidekiq bundle exec sidekiq --version
```

Expected: prints the Sidekiq version without errors.

If Redis connection fails:
- Confirm the `redis` container is running (Step 1)
- Confirm `REDIS_URL` is set in `.env`
- Try: `docker compose restart redis`

---

### Step 6 — Quick smoke test

```bash
docker compose exec web rails runner "puts 'Rails OK'"
```

Expected output: `Rails OK`

If this fails, the app cannot boot. Check `docker compose logs web --tail=50`
and report the error before proceeding.

---

## All Checks Pass

Report back:
```
✅ Containers: running
✅ Gems: installed
✅ Database: connected
✅ Migrations: all up
✅ Redis: connected
✅ Rails boot: OK

Environment is healthy. Ready to work on tickets.
```

## Any Check Fails

Report exactly which step failed and the full error output.
Do not proceed to ticket work until all checks pass.
