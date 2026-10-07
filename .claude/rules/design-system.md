---
paths:
  - "app/views/**"
  - "app/assets/stylesheets/**"
  - "app/javascript/controllers/**"
  - "app/helpers/**"
---

# Design system

**Read `DESIGN.md` before writing any view or CSS.** It defines the tokens (color,
type, spacing, radius), the components, and the page shell. This file is the rules
for applying it.

## Rules

- Dark is the default theme (`data-theme="dark"` on `<html>`). Every page works in both.
- The Google Fonts link tag stays in `application.html.erb`.
- Colors, fonts, spacing: CSS variables only — `var(--text-primary)`, `var(--space-6)`.
  No hex values, no raw px.
- Tailwind is for layout only — flex, grid, positioning, display, overflow. No Tailwind
  color, font, or spacing utilities.
- **No inline `style="..."`.** Define a named class. (Some older views still have inline
  styles — don't add more, and don't clean up ones outside your ticket.)
- Severity badges use `var(--font-mono)`.
- `--accent` (amber) is never used for destructive actions — use `var(--critical)`.
- Primary CTAs use uppercase tracking.
- No drop shadows in dark mode — elevation comes from borders and background.
- Text inputs use the existing `.form-field` / `.form-label` / `.form-input` / `.form-hint`
  classes in `app/assets/stylesheets/components/forms.css`.

## Where new CSS goes

- Component → `app/assets/stylesheets/components/<name>.css`
- Page → `app/assets/stylesheets/pages/<name>.css`
- Global → `app/assets/stylesheets/application.css`

## Scope of styling tickets

"Fix / improve / style the X" means change X and nothing else. No new card wrappers,
no re-centering, no max-width changes, no DOM restructuring. Layout changes need their
own ticket. If you're unsure whether something is in scope, it isn't.

## Assets in development

Propshaft serves `app/assets/` directly. Never run `rails assets:precompile` in
development. If `public/assets/` exists it shadows the source files and CSS changes
won't show — delete it: `docker compose exec web rm -rf public/assets`.

## Before committing a view

- [ ] No inline styles, hex colors, or Tailwind color/font/spacing utilities
- [ ] Right font variable for each text role
- [ ] Works in both themes (toggle `data-theme` on `<html>`)
- [ ] Interactive elements have hover states using variables
