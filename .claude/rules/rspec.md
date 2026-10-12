---
paths:
  - "spec/**"
---

# RSpec

Factories only (`spec/factories/`), no fixtures.

Spec paths mirror `app/`. Controllers are tested with request specs in
`spec/requests/`, never controller specs.

## Patterns used here

- Request specs `include Devise::Test::IntegrationHelpers` and `sign_in user`.
  `spec/requests/apps_spec.rb` is the reference.
- Workspace roles: `create(:workspace_membership, user:, workspace:, role: :admin)`.
  There are no role traits on the user factory.
- Policy specs call the predicate directly: `expect(policy.show?).to be true`.
  Cover every role plus a non-member. `spec/policies/workspace_policy_spec.rb` is the reference.
- Non-members get 404, not 403. Exception: `ReportsController` returns 403.
  Specs match the controller's actual behavior; never change a controller to make a spec pass.

## Rules

- Never make real HTTP or LLM calls. Stub at the service boundary
  (`allow(ScrapingService).to receive(:fetch)`, `allow(LlmService).to receive(...)`),
  as `spec/jobs/report_job_spec.rb` does.
- `let`, not `let!`, unless the record must exist before the example runs.
- `build` when the record doesn't need to be persisted, `create` when it does.
- One expectation per example where practical.