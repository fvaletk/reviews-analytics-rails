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

Broadcast with `Turbo::StreamsChannel.broadcast_*_to`; the view subscribes with
`turbo_stream_from` using the same streamables. Reference: notifications —
`ReportJob#broadcast_notification` prepends `notifications/notification` into
`notification_list`, subscribed in `layouts/_navbar.html.erb` via
`turbo_stream_from current_user, :notifications`.

- Partials used in broadcasts take locals only, no instance variables (jobs have no
  controller context).
- Broadcast targets are DOM ids that exist on every page that subscribes.

## Legacy: raw ActionCable

Report status (`ReportChannel` → `report_status_controller.js`) sends JSON and
patches the DOM in Stimulus. Don't extend this pattern for new features; use Turbo
Streams.
