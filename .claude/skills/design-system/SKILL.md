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

## Building a Form Input

Always use the `.form-input` class for all text inputs, never raw Tailwind utility
classes on input elements — Tailwind JIT may not scan ERB files reliably.

```erb
<div class="form-field">
  <%= f.label :name, "Field Label", class: "form-label" %>
  <%= f.text_field :name,
        placeholder: "Placeholder text...",
        class: "form-input" %>
</div>
```

The classes are defined in `app/assets/stylesheets/components/forms.css`:

```css
.form-field {
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
}

.form-label {
  font-family: var(--font-body);
  font-size: var(--text-sm);
  font-weight: 500;
  color: var(--text-secondary);
  letter-spacing: var(--tracking-wider);
  text-transform: uppercase;
}

.form-input {
  display: block;
  width: 100%;
  border-radius: var(--radius-md);
  border: 1px solid var(--border-strong);
  background: var(--bg-subtle);
  color: var(--text-primary);
  font-family: var(--font-body);
  font-size: var(--text-base);
  padding: var(--space-3) var(--space-4);
  transition: border-color 150ms ease;
}
.form-input:focus {
  outline: none;
  border-color: var(--accent);
  box-shadow: 0 0 0 2px var(--accent-dim);
}
.form-input::placeholder {
  color: var(--text-tertiary);
}

.form-hint {
  font-family: var(--font-mono);
  font-size: var(--text-xs);
  color: var(--text-tertiary);
}
```

Use `.form-hint` for helper text below a field:
```erb
<p class="form-hint">The store ID is parsed automatically from the URL.</p>
```

**Never** apply Tailwind color, font, or spacing utilities directly on `<input>`
elements — use `.form-input` and the classes above exclusively.

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

## Scope of Styling Changes

When a ticket asks to "improve", "fix", or "style" a specific element — that means
touching **only that element**. Never restructure the surrounding layout unless the
ticket explicitly asks for it.

Examples:
- "Fix the input styling" → change classes on the `<input>` only
- "Improve the button" → change classes on the `<button>` only
- "Style the label" → change classes on the `<label>` only

**Never** add card wrappers, change page centering, adjust max-widths, or restructure
the DOM in response to a styling ticket. If the layout needs changing, that is a
separate ticket with an explicit layout description.

If you are unsure whether a change is in scope — it isn't. Do only what is stated.

## No Inline Styles

Never use `style="..."` attributes in ERB views. Always define a CSS class instead.

```erb
<%# ❌ Wrong — inline styles %>
<span style="font-family: var(--font-mono); font-size: var(--text-sm); color: var(--text-secondary);">
  label
</span>

<%# ✅ Correct — named class %>
<span class="meta-label">label</span>
```

```css
/* Define the class in the relevant stylesheet */
.meta-label {
  font-family: var(--font-mono);
  font-size: var(--text-sm);
  color: var(--text-secondary);
}
```

The only exception is Tailwind layout utilities (`flex`, `grid`, `items-center`, `gap-4`, etc.) which are utility-first by design. Everything else — colors, fonts, spacing, borders — must be a named class using CSS variables.

Where to put new CSS classes:
- Component-specific styles → `app/assets/stylesheets/components/<component_name>.css`
- Page-specific styles → `app/assets/stylesheets/pages/<page_name>.css`
- Global/shared styles → `app/assets/stylesheets/application.css`

## Checklist Before Committing Any View

- [ ] No inline `style="..."` attributes — every style is a named CSS class
- [ ] No hardcoded hex colors — only `var(--...)` tokens
- [ ] Correct font variable used for each text role
- [ ] Spacing uses `var(--space-N)` tokens
- [ ] Page works in both themes (toggle `data-theme` on `<html>` to verify)
- [ ] Severity badges use `var(--font-mono)`
- [ ] No Tailwind color or font utilities used
- [ ] Interactive elements have hover states using CSS variables
