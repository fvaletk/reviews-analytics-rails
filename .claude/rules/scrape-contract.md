---
paths:
  - "app/services/scraping_service.rb"
  - "spec/services/scraping_service_spec.rb"
---

# Scraping contract (consumer side)

`ScrapingService` calls `POST /scrape` on the FastAPI service. The contract is owned by
`~/Projects/reviews-analytics-fastapi` — request and response models in
`app/models/scrape.py`, semantics in `.claude/rules/scrape-contract.md` there.

- Any change to the request or response shape is a two-repo change. Don't change one side alone.
- The HTTP timeout is 120 seconds (`TIMEOUT_SECONDS`); a full two-store scrape takes 20–60.
- Reviews are upserted on `(app_id, store, external_id)`.
- `partial: true` means one store failed; the reviews from the other are still valid. Don't rely
  on it alone — today a store failure can also come back as an empty list with `partial: false`.
