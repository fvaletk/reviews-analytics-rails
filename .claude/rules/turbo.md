---
paths:
  - "app/views/**"
  - "app/javascript/**"
  - "app/jobs/**/*.rb"
  - "app/channels/**/*.rb"
  - "app/controllers/**/*.rb"
---

# Hotwire (Turbo + Stimulus)

Turbo handles page updates. Stimulus handles behavior. Never write `fetch()` or
`XMLHttpRequest` by hand.

## Turbo Streams from jobs

Broadcast after each status change; the view subscribes to the same stream name.

```ruby
Turbo::StreamsChannel.broadcast_replace_to(
  "report_#{report.id}",
  target: "report_status",
  partial: "reports/status",
  locals: { report: report }
)
```

```erb
<%= turbo_stream_from "report_#{@report.id}" %>
<div id="report_status"><%= render "reports/status", report: @report %></div>
```

- Partials used in broadcasts take locals only — no instance variables.
- Broadcast targets have a stable `id`.

## Controllers

Turbo Stream response for in-page updates, redirect for full navigations. Always
include a `format.html` fallback.

## Links and buttons

- DELETE links: `data-turbo-method="delete"`. Destructive actions: `data-turbo-confirm`.
- **Anything that redirects off-site (OAuth, payments, SSO)** uses `button_to … method: :post,
  data: { turbo: false }` — never `link_to`. OAuth needs a POST, and Turbo intercepting the
  form breaks the redirect cycle.

## Stimulus

Client-side behavior only — toggling visibility, ActionCable subscriptions, DOM updates.
Unsubscribe in `disconnect()`.
