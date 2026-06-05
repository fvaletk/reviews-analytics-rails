# DESIGN.md — Reviews Analytics

## Design Philosophy

**Editorial Intelligence.** This is a research tool for people who make product decisions.
The aesthetic draws from financial terminals, investigative journalism, and high-end research
publications. Information is dense but never cluttered. Every visual decision earns its place.

The design avoids: dashboards that look like Tailwind templates, purple gradients, card grids
with rounded corners everywhere, icon overload, confetti illustrations.

The design pursues: typographic hierarchy, deliberate negative space, a single sharp accent,
motion that reveals rather than decorates.

---

## Color Tokens

Two modes. Dark is primary. Light is equally intentional — think archival paper, not white glare.

```css
:root[data-theme="dark"] {
  /* Backgrounds */
  --bg-base:        #0D0D0D;   /* near-black canvas */
  --bg-surface:     #141414;   /* cards, panels */
  --bg-elevated:    #1C1C1C;   /* dropdowns, modals */
  --bg-subtle:      #222222;   /* hover states, input fills */

  /* Borders */
  --border-default: #2A2A2A;
  --border-strong:  #3D3D3D;

  /* Text */
  --text-primary:   #F0EBE3;   /* warm off-white — not pure #FFF */
  --text-secondary: #9A9080;   /* muted, warm gray */
  --text-tertiary:  #5C5650;   /* timestamps, metadata */
  --text-inverse:   #0D0D0D;

  /* Accent — a single sharp amber */
  --accent:         #E8A838;
  --accent-dim:     #3D2E0F;   /* accent backgrounds, badges */
  --accent-hover:   #F0BC5A;

  /* Semantic */
  --critical:       #E05252;
  --critical-dim:   #3D1515;
  --high:           #D4763A;
  --high-dim:       #3D2010;
  --medium:         #C9A227;
  --medium-dim:     #3D2F0A;
  --low:            #5C9E6E;
  --low-dim:        #152B1E;

  /* Status */
  --status-pending:   #5C5650;
  --status-fetching:  #4A7FC1;
  --status-analyzing: #C9A227;
  --status-complete:  #5C9E6E;
  --status-failed:    #E05252;
}

:root[data-theme="light"] {
  /* Backgrounds */
  --bg-base:        #F5F0E8;   /* warm parchment */
  --bg-surface:     #FDFAF5;   /* cards, panels */
  --bg-elevated:    #FFFFFF;
  --bg-subtle:      #EDE8DE;

  /* Borders */
  --border-default: #D8D0C4;
  --border-strong:  #B8B0A4;

  /* Text */
  --text-primary:   #1A1714;
  --text-secondary: #6B6460;
  --text-tertiary:  #9A9490;
  --text-inverse:   #F5F0E8;

  /* Accent — same amber, adjusted */
  --accent:         #C8880A;
  --accent-dim:     #F5E8CC;
  --accent-hover:   #A06A00;

  /* Semantic — same hues, lighter backgrounds */
  --critical:       #C03030;
  --critical-dim:   #FDEAEA;
  --high:           #B85C20;
  --high-dim:       #FDEEDE;
  --medium:         #A07A00;
  --medium-dim:     #FDF5DC;
  --low:            #3A7850;
  --low-dim:        #E4F2E8;

  /* Status */
  --status-pending:   #9A9490;
  --status-fetching:  #3A60A0;
  --status-analyzing: #A07A00;
  --status-complete:  #3A7850;
  --status-failed:    #C03030;
}
```

---

## Typography

Two fonts. One for hierarchy, one for reading. Both loaded from Google Fonts.

```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=DM+Serif+Display:ital@0;1&family=DM+Mono:wght@400;500&family=Instrument+Sans:wght@400;500;600&display=swap" rel="stylesheet">
```

```css
:root {
  /* Display — section titles, report headings, hero text */
  --font-display:  'DM Serif Display', Georgia, serif;

  /* Body — all UI text, labels, descriptions */
  --font-body:     'Instrument Sans', system-ui, sans-serif;

  /* Mono — IDs, timestamps, store tags, metadata, code */
  --font-mono:     'DM Mono', 'Courier New', monospace;
}
```

### Type Scale

```css
--text-xs:   0.6875rem;   /* 11px — metadata, timestamps */
--text-sm:   0.8125rem;   /* 13px — labels, badges, secondary */
--text-base: 0.9375rem;   /* 15px — body text */
--text-lg:   1.0625rem;   /* 17px — emphasized body */
--text-xl:   1.25rem;     /* 20px — card titles */
--text-2xl:  1.625rem;    /* 26px — page section headings */
--text-3xl:  2.25rem;     /* 36px — page titles */
--text-4xl:  3.25rem;     /* 52px — display / hero */

--leading-tight:  1.2;
--leading-normal: 1.5;
--leading-relaxed: 1.7;   /* long-form report text */

--tracking-tight:  -0.03em;
--tracking-normal:  0;
--tracking-wide:    0.06em;
--tracking-wider:   0.12em;  /* ALL-CAPS labels, badges */
```

---

## Spacing

Base unit: `4px`. Everything is a multiple.

```css
--space-1:  0.25rem;   /* 4px */
--space-2:  0.5rem;    /* 8px */
--space-3:  0.75rem;   /* 12px */
--space-4:  1rem;      /* 16px */
--space-5:  1.25rem;   /* 20px */
--space-6:  1.5rem;    /* 24px */
--space-8:  2rem;      /* 32px */
--space-10: 2.5rem;    /* 40px */
--space-12: 3rem;      /* 48px */
--space-16: 4rem;      /* 64px */
--space-20: 5rem;      /* 80px */
--space-24: 6rem;      /* 96px */
```

---

## Borders & Radius

This design is editorial, not rounded. Use radius sparingly.

```css
--radius-sm:   3px;    /* badges, tags */
--radius-md:   6px;    /* inputs, buttons */
--radius-lg:   10px;   /* cards, panels */
--radius-full: 9999px; /* pill badges only */
```

---

## Shadows (dark mode)

No drop shadows in dark mode — use borders and background elevation instead.
Light mode uses subtle shadows.

```css
/* Light mode only */
--shadow-sm: 0 1px 3px rgba(0,0,0,0.08), 0 1px 2px rgba(0,0,0,0.06);
--shadow-md: 0 4px 12px rgba(0,0,0,0.10), 0 2px 4px rgba(0,0,0,0.06);
--shadow-lg: 0 12px 32px rgba(0,0,0,0.12), 0 4px 8px rgba(0,0,0,0.06);
```

---

## Component Patterns

### Navbar

Fixed top. Full width. Hairline border bottom. No background blur.

```
[Logo / App Name]                    [Bell icon + badge]  [Avatar]
```

- Height: `52px`
- Background: `var(--bg-base)`
- Border-bottom: `1px solid var(--border-default)`
- Logo: `var(--font-display)`, `var(--text-xl)`, `var(--accent)` color
- Nav links: `var(--font-body)`, `var(--text-sm)`, `var(--tracking-wider)`, uppercase

### Buttons

Three variants. No gradients. No rounded-full on primary actions.

```css
/* Primary */
.btn-primary {
  background: var(--accent);
  color: var(--text-inverse);
  font-family: var(--font-body);
  font-size: var(--text-sm);
  font-weight: 600;
  letter-spacing: var(--tracking-wider);
  text-transform: uppercase;
  padding: var(--space-3) var(--space-6);
  border-radius: var(--radius-md);
  border: none;
  transition: background 150ms ease;
}
.btn-primary:hover { background: var(--accent-hover); }

/* Secondary */
.btn-secondary {
  background: transparent;
  color: var(--text-primary);
  border: 1px solid var(--border-strong);
  /* same font/size/padding as primary */
}
.btn-secondary:hover { border-color: var(--text-secondary); }

/* Ghost — destructive or low-emphasis */
.btn-ghost {
  background: transparent;
  color: var(--text-secondary);
  border: none;
  /* same font/size, reduced padding */
}
.btn-ghost:hover { color: var(--text-primary); }
```

### Cards / Panels

```css
.card {
  background: var(--bg-surface);
  border: 1px solid var(--border-default);
  border-radius: var(--radius-lg);
  padding: var(--space-6);
}
/* Hover state for interactive cards */
.card-interactive:hover {
  border-color: var(--border-strong);
  background: var(--bg-elevated);
}
```

### Severity Badges

Used throughout the report. Uppercase, monospace, small.

```css
.badge {
  font-family: var(--font-mono);
  font-size: var(--text-xs);
  font-weight: 500;
  letter-spacing: var(--tracking-wider);
  text-transform: uppercase;
  padding: 2px var(--space-2);
  border-radius: var(--radius-sm);
}
.badge-critical  { background: var(--critical-dim);  color: var(--critical); }
.badge-high      { background: var(--high-dim);      color: var(--high); }
.badge-medium    { background: var(--medium-dim);    color: var(--medium); }
.badge-low       { background: var(--low-dim);       color: var(--low); }
```

### Status Indicator

A subtle animated dot for live job status.

```css
.status-dot {
  display: inline-block;
  width: 7px;
  height: 7px;
  border-radius: var(--radius-full);
  background: currentColor;
}
/* Pulse only during active states */
.status-dot.is-active {
  animation: pulse 1.8s ease-in-out infinite;
}
@keyframes pulse {
  0%, 100% { opacity: 1; transform: scale(1); }
  50%       { opacity: 0.4; transform: scale(0.75); }
}
```

### Form Inputs

```css
.input {
  background: var(--bg-subtle);
  border: 1px solid var(--border-default);
  border-radius: var(--radius-md);
  color: var(--text-primary);
  font-family: var(--font-body);
  font-size: var(--text-base);
  padding: var(--space-3) var(--space-4);
  transition: border-color 150ms ease;
  width: 100%;
}
.input:focus {
  outline: none;
  border-color: var(--accent);
}
.input::placeholder { color: var(--text-tertiary); }
```

### Notification Bell Badge

```css
.bell-wrapper { position: relative; }
.bell-badge {
  position: absolute;
  top: -4px;
  right: -6px;
  background: var(--accent);
  color: var(--text-inverse);
  font-family: var(--font-mono);
  font-size: 10px;
  font-weight: 500;
  min-width: 17px;
  height: 17px;
  border-radius: var(--radius-full);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0 var(--space-1);
}
```

---

## Theme Toggle

Store preference in `localStorage` and on `<html data-theme="...">`.

```javascript
// Stimulus controller: theme_toggle_controller.js
const saved = localStorage.getItem('theme') || 'dark'
document.documentElement.setAttribute('data-theme', saved)

toggle() {
  const next = current === 'dark' ? 'light' : 'dark'
  document.documentElement.setAttribute('data-theme', next)
  localStorage.setItem('theme', next)
}
```

Default is always **dark**. Respect `prefers-color-scheme` on first visit only.

---

## Layout

### Page Shell

```
┌─────────────────────────────────────────┐
│  Navbar (fixed, 52px)                   │
├─────────────────────────────────────────┤
│                                         │
│  Main content                           │
│  max-width: 1100px                      │
│  margin: 0 auto                         │
│  padding: var(--space-12) var(--space-6)│
│                                         │
└─────────────────────────────────────────┘
```

### Report Layout

Two-column on wide screens. Single column on mobile.

```
┌──────────────────────┬──────────────────┐
│  Left (65%)          │  Right (35%)     │
│  Pain points         │  Summary         │
│  Complaints          │  Store breakdown │
│  Feature requests    │  Meta info       │
│                      │  Re-gen buttons  │
└──────────────────────┴──────────────────┘
```

---

## Motion Principles

Less is more. Animate only what carries meaning.

```css
/* Standard transition for interactive elements */
--transition-fast:   100ms ease;
--transition-base:   150ms ease;
--transition-slow:   250ms ease;
--transition-reveal: 400ms cubic-bezier(0.16, 1, 0.3, 1); /* entrances */
```

**Use animation for:**
- Page entrances — staggered fade + translate-up on load
- Status transitions — the status dot pulse
- Notification badge appearing — scale from 0
- Dropdown open/close — height + opacity

**Never animate:**
- Colors on hover (use `transition: background` sparingly)
- Decorative elements that aren't interactive
- Anything that loops without user intent (except the status dot)

---

## Rules for Sub-agents

1. Always import the font link tag in `application.html.erb`
2. Always define all CSS variables in `:root[data-theme="dark"]` and `:root[data-theme="light"]`
3. Default `data-theme` attribute on `<html>` is `"dark"`
4. Never use hardcoded color values — only CSS variables
5. Never use Tailwind utility classes for colors — use the variable system above
6. Tailwind is allowed for spacing, flex, grid, and layout utilities only
7. Severity badges always use `var(--font-mono)` — never body font
8. The accent color is amber — never use it for destructive actions (use `var(--critical)`)
9. Buttons use uppercase tracking — never sentence case on primary CTAs
10. All new pages must work in both themes — test by toggling `data-theme`