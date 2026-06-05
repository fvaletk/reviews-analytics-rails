# /work-next-ticket

Fetches the next Todo ticket from Linear, runs it through the full agent pipeline, and marks it Done.

## What This Command Does

1. Fetches the next **Todo** ticket from Linear (project: `reviews-analytics-app`, team: `Brain Spark`)
2. Reads the full ticket — title, description, and acceptance criteria
3. **Validates the ticket is unambiguous** — stops and asks you if anything is unclear
4. Marks the ticket **In Progress** in Linear
5. Spawns the **implement** agent with the full ticket content
6. Spawns the **test** agent with the acceptance criteria and list of modified files
7. Spawns the **commit** agent with the ticket ID and title
8. Marks the ticket **Done** in Linear if the commit agent reports success

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
Test results: <summary from test agent>
```

## Failure Handling

| Failure point | Action |
|---|---|
| Implement agent reports ambiguity | Stop, surface to you, wait for clarification |
| Test agent finds failing tests | Stop, report failures, do not commit |
| Test agent uncovers implementation bug | Stop, report to you — do not auto-fix |
| Commit agent cannot push | Stop, report the git error |

On any failure, the ticket stays **In Progress** in Linear. Fix the issue manually, then run `/work-next-ticket` again — it will detect the in-progress ticket and resume from the commit step.

## Linear State Management

| Step | Linear status |
|---|---|
| Ticket fetched | Todo |
| Validation passed | In Progress |
| All agents done + pushed | Done |
| Any failure | In Progress (stays) |