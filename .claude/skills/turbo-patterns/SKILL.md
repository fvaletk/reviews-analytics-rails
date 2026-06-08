# Skill: turbo-patterns

## Core Principle

Turbo handles page updates. Stimulus handles behavior. No custom fetch/XHR.

## Turbo Frames

Use for scoped page regions that update independently.

```erb
<%# Wraps a region that can be replaced without a full page reload %>
<%= turbo_frame_tag "report_status" do %>
  <p>Status: <%= @report.status %></p>
<% end %>
```

The controller responds normally — Turbo extracts the matching frame from the response.

## Turbo Streams (from controllers)

Use for multi-target updates in response to a form submission.

```ruby
# Controller
def create
  @report = Report.create!(...)
  ReportJob.perform_later(@report.id)

  respond_to do |format|
    format.turbo_stream do
      render turbo_stream: turbo_stream.replace(
        "report_status",
        partial: "reports/status",
        locals: { report: @report }
      )
    end
    format.html { redirect_to @report }
  end
end
```

## Turbo Streams (from jobs via ActionCable)

Broadcast from inside the job after each status change.

```ruby
# Inside ReportJob
report.update!(status: :fetching)
Turbo::StreamsChannel.broadcast_replace_to(
  "report_#{report.id}",
  target: "report_status",
  partial: "reports/status",
  locals: { report: report }
)
```

The view subscribes with:
```erb
<%= turbo_stream_from "report_#{@report.id}" %>

<div id="report_status">
  <%= render "reports/status", report: @report %>
</div>
```

## Stimulus Controllers

Use for client-side behavior only — toggling visibility, subscriptions, DOM updates from ActionCable.

```javascript
// notification_badge_controller.js
import { Controller } from "@hotwired/stimulus"
import consumer from "channels/consumer"

export default class extends Controller {
  static targets = ["count"]

  connect() {
    this.subscription = consumer.subscriptions.create("NotificationChannel", {
      received: (data) => {
        this.countTarget.textContent = data.unread_count
        this.countTarget.hidden = data.unread_count === 0
      }
    })
  }

  disconnect() {
    this.subscription?.unsubscribe()
  }
}
```

## OAuth and External Redirects

Never use `link_to` for OAuth initiation. OAuth requires a POST request — an
`<a>` tag sends GET and will cause the authentication flow to fail.

Always use `button_to` with `method: :post` and `data: { turbo: false }`:

```erb
<%= button_to user_google_oauth2_omniauth_authorize_path,
      method: :post,
      data: { turbo: false },
      class: "btn-primary" do %>
  <img src="https://www.svgrepo.com/show/475656/google-color.svg"
       alt="Google" class="h-5 w-5 mr-2">
  Sign in with Google
<% end %>
```

`data: { turbo: false }` is mandatory — Turbo intercepts form submissions by
default and breaks the OAuth redirect cycle if omitted. Any link or button that
triggers an external redirect (OAuth, payment providers, third-party SSO) must
have `data: { turbo: false }`.

## Rules

- Never write `fetch()` or `XMLHttpRequest` manually — Turbo handles it
- `data-turbo-method="delete"` on links that trigger DELETE requests
- `data-turbo-confirm="Are you sure?"` on destructive actions
- Partials used in broadcasts must be self-contained — no instance variables, only locals
- Always give broadcast target divs a stable `id` attribute