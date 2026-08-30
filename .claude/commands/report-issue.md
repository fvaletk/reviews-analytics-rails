---
description: Log the issue from this conversation into the Reviewly vault
---

Capture the issue or finding **from this conversation** into the Obsidian vault.

**Takes no arguments.** The source is what we have been discussing in this session. Do not ask the user to describe the issue — they already have, above.

## Step 1: Find what to capture

Look back over this conversation and identify the problem, bug, surprise, or finding under discussion. Usually it is the most recent substantial thread.

- **Several distinct issues discussed?** List them in one line each and ask which to capture, offering "all" as an option. Write one file per issue.
- **No issue in the conversation?** Say so plainly and stop. Do not invent one, and do not fall back to scanning the codebase for problems.
- If arguments were passed anyway, treat them as a hint about *which* thread to capture, not as the content.

## Step 2: Preserve, don't re-derive

The investigation already happened in this conversation. Your job is to not lose it — not to redo it. Pull directly from what was established here:

- The symptom, in the terms it was actually described
- The root cause **if it was found**; if it wasn't, say so rather than guessing one now
- Exact file paths and line numbers, with the relevant code in fenced blocks
- How it was reproduced or observed
- **What was ruled out** — the wrong theories are often the most valuable part, because they stop the next session re-walking them
- What is still unknown

Only read files to confirm a path or line number you are unsure of. Do not open a fresh investigation.

If something was asserted in conversation but never verified, carry it over **labelled as unverified**. Do not launder a hypothesis into a fact by writing it down.

## Step 3: Write the finding

Path: `~/Projects/Capri/01-projects/reviewly/findings/YYYY-MM-DD-short-slug.md`

If that filename exists, append `-2`. Never overwrite a finding.

```markdown
---
type: finding
project: reviewly
repo: reviews-analytics-rails
status: new
severity: bug | improvement | question | risk
date: YYYY-MM-DD
branch: <current git branch>
commit: <short sha>
ticket:
---

# One-line title, specific and outcome-shaped

## What
The problem, as established in the conversation.

## Where
Exact file paths with line numbers. Relevant code in fenced blocks.

## Why it matters
The consequence. If a user would never notice, say that — it changes the priority.

## What we found
The reasoning from the conversation. Root cause if identified.

## Ruled out
Theories considered and eliminated, and why. Omit only if nothing was ruled out.

## Still unknown
Open questions. Omit if there are none.

## Suggested action
A recommendation, not a decision.
```

Fill `branch` and `commit` from git. Leave `ticket:` empty — `/triage-findings` fills it.

Before writing, check `~/Projects/Capri/01-projects/reviewly/findings/` and the "Known-wrong things" section of `analysis/current-understanding.md` for the same issue. If it is already captured, say so and stop rather than filing a duplicate.

## Step 4: Report back

One line: the path written and the title. Nothing more — this runs mid-work and should not derail the session.

## Rules

- Capture only. No Linear ticket, no code changes, no fixes — not even trivial ones. Triage happens later via `/triage-findings`.
- One finding per file.
- Suggested labels for triage, if obvious from context: `rails`, `frontend`, `jobs`, `schema`, `auth`, `infra`, plus a type label (`Bug` / `Feature` / `Improvement`).
- Never edit or delete an existing finding.
