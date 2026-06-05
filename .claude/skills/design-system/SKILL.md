# Skill: design-system

## When to Load This Skill

Load this skill for any ticket that touches:
- Views (`.erb` files)
- Layouts (`application.html.erb`, partials)
- Stimulus controllers that affect the UI
- Any new page, component, or UI element

## First Step — Always

Before writing any view or CSS, read `DESIGN.md` at the project root.
It is the single source of truth for colors, typography, spacing, and components.

---

## Quick Reference

### Theme

The app has two themes. Dark is the default.
All color values come from CSS variables — never hardcode hex values.

```erb
<%# In application.html.erb — set default theme %>
<html data-theme="dark" lang="en">
```

```css
/* Always use variables, never raw colors */
color: var(--text-primary);       /* ✅ */
color: #F0EBE3;                    /* ❌ */
```

### Fonts

Three fonts are in use. Use each in its designated role.

| Variable | Font | Use for |
|---|---|---|
| `var(--font-display)` | DM Serif Display | Page titles, report section headings |
| `var(--font-body)` | Instrument Sans | All UI text, labels, descriptions |
| `var(--font-mono)` | DM Mono | Badges, timestamps, IDs, metadata |

### Spacing

Use `var(--space-N)` tokens only. No arbitrary values.

```css
padding: var(--space-6);           /* ✅ */
padding: 24px;                     /* ❌ */
```

### Tailwind Usage

Tailwind is allowed for layout only — flex, grid, positioning, display, overflow.
Never use Tailwind color, font, or spacing utilities.

```erb
<%# ✅ Tailwind for layout, variables for design %>
<div class="flex items-center gap-4" style="color: var(--text-secondary)">

<%# ❌ Never use Tailwind for colors or typography %>
<div class="text-gray-400 font-medium">
```

---

## Building a New Page

Every page follows this shell:

```erb
<%# Wrap page content in the standard container %>
<main class="page-container">
  <header class="page-header">
    <h1 class="page-title">Page Title</h1>
  </header>

  <div class="page-body">
    <%# content here %>
  </div>
</main>
```

```css
.page-container {
  max-width: 1100px;
  margin: 0 auto;
  padding: var(--space-12) var(--space-6);
}
.page-title {
  font-family: var(--font-display);
  font-size: var(--text-3xl);
  color: var(--text-primary);
  letter-spacing: var(--tracking-tight);
}
```

---

## Building a Card

```erb
<div class="card">
  <h2 class="card-title">Title</h2>
  <p class="card-body">Content</p>
</div>
```

```css
.card {
  background: var(--bg-surface);
  border: 1px solid var(--border-default);
  border-radius: var(--radius-lg);
  padding: var(--space-6);
}
.card-title {
  font-family: var(--font-body);
  font-size: var(--text-xl);
  font-weight: 600;
  color: var(--text-primary);
  margin-bottom: var(--space-3);
}
```

---

## Building a Severity Badge

```erb
<span class="badge badge-<%= severity %>"><%= severity %></span>
```

Severity values: `critical`, `high`, `medium`, `low`
Frequency/demand values use the same badge classes.

---

## Building a Button

```erb
<%# Primary CTA %>
<%= button_to "Generate Report", path, class: "btn-primary" %>

<%# Secondary %>
<%= link_to "View History", path, class: "btn-secondary" %>

<%# Destructive ghost %>
<%= button_to "Remove", path, method: :delete,
    data: { turbo_confirm: "Are you sure?" },
    class: "btn-ghost" %>
```

---

## Theme Toggle Button

Place in the navbar partial:

```erb
<div data-controller="theme-toggle">
  <button data-action="click->theme-toggle#toggle"
          class="btn-ghost"
          aria-label="Toggle theme">
    <%# Sun/moon icon — swap via JS %>
    <span data-theme-toggle-target="icon">☽</span>
  </button>
</div>
```

---

## Status Indicators (live job status)

```erb
<div id="report_status" data-controller="report-status"
     data-report-status-report-id-value="<%= @report.id %>">
  <%= render "reports/status_indicator", report: @report %>
</div>
```

```erb
<%# _status_indicator.html.erb %>
<div class="flex items-center" style="gap: var(--space-2)">
  <span class="status-dot <%= report.pending? || report.complete? ? '' : 'is-active' %>"
        style="color: var(--status-<%= report.status %>)"></span>
  <span style="font-family: var(--font-mono); font-size: var(--text-sm);
               color: var(--text-secondary); text-transform: uppercase;
               letter-spacing: var(--tracking-wider);">
    <%= report.status %>
  </span>
</div>
```

---

## Checklist Before Committing Any View

- [ ] No hardcoded hex colors — only `var(--...)` tokens
- [ ] Correct font variable used for each text role
- [ ] Spacing uses `var(--space-N)` tokens
- [ ] Page works in both themes (toggle `data-theme` on `<html>` to verify)
- [ ] Severity badges use `var(--font-mono)`
- [ ] No Tailwind color or font utilities used
- [ ] Interactive elements have hover states using CSS variables