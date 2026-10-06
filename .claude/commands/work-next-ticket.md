# /work-next-ticket

Fetches the next Todo ticket from Linear, runs it through the full agent pipeline on its own branch, and opens a pull request into `staging` for the user to review.

## What This Command Does

1. Fetches the next **Todo** ticket from Linear (project: `Reviewly`, team: `Brain Spark`)
2. Reads the full ticket — title, description, acceptance criteria, and `gitBranchName`
3. **Validates the ticket is unambiguous** — stops and asks you if anything is unclear
4. Marks the ticket **In Progress** in Linear
5. **Creates the ticket branch** from the latest `staging`, named exactly the ticket's `gitBranchName`
   (stops if the working tree isn't clean; checks out the existing branch when resuming)
6. Spawns the **implement** agent with the full ticket content
7. Spawns the **test** agent with the acceptance criteria and list of modified files
8. Spawns the **commit** agent with the ticket ID, title, URL, and branch name — it pushes the branch and opens a PR into `staging`
9. Comments the PR URL on the Linear ticket and **stops**. The ticket stays **In Progress** until you merge the PR and mark it Done.

Never pushes to `staging` or `main`, never merges, never marks a ticket Done. (Human review gate added 2026-10-06.)

## How to Run

```
/work-next-ticket
```

No arguments needed. The orchestrator fetches the next ticket automatically.

To work on a specific ticket instead:
```
/work-next-ticket BRA-12
```

## Validation Gate

Before spawning any agent, the orchestrator reads the ticket and checks:

- Does every acceptance criterion have a clear, testable definition of done?
- Are all referenced models, services, and routes already established in the codebase or defined in a prior ticket?
- Is the scope contained to a single concern?

If **any** of these fail → stop and ask you for clarification. Do not proceed with ambiguous tickets.

## Agent Handoff Protocol

Each agent receives an explicit context block — never assume agents share state.

**Implement agent receives:**
```
Ticket ID: BRA-XX
Title: <title>
Description: <full description>
Acceptance Criteria:
- [ ] criterion 1
- [ ] criterion 2
...
```

**Test agent receives:**
```
Ticket ID: BRA-XX
Acceptance Criteria:
- [ ] criterion 1
- [ ] criterion 2
...
Files created or modified by implement agent:
- app/models/workspace.rb
- app/controllers/workspaces_controller.rb
...
```

**Commit agent receives:**
```
Ticket ID: BRA-XX
Title: <title>
Ticket URL: <linear url>
Branch: <gitBranchName>
Test results: <summary from test agent>
```

## Failure Handling

| Failure point | Action |
|---|---|
| Implement agent reports ambiguity | Stop, surface to you, wait for clarification |
| Test agent finds failing tests | Stop, report failures, do not commit |
| Test agent uncovers implementation bug | Stop, report to you — do not auto-fix |
| Working tree not clean before branching | Stop, ask you — never stash or discard |
| Commit agent cannot push | Stop, report the git error |
| `gh` unavailable | Report the GitHub compare URL instead of a PR URL |

On any failure, the ticket stays **In Progress** in Linear. Fix the issue manually, then run `/work-next-ticket` again — it will detect the in-progress ticket, check out its existing branch, and resume from the commit step.

## Linear State Management

| Step | Linear status |
|---|---|
| Ticket fetched | Todo |
| Validation passed | In Progress |
| PR opened | In Progress (stays — PR URL commented on the ticket) |
| You merge the PR | You mark it Done |
| Any failure | In Progress (stays) |

Because the ticket stays In Progress until you merge, the orchestrator's WIP guard won't feed the next ticket until you've reviewed this one.