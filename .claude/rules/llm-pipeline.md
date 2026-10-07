---
paths:
  - "app/services/llm_service.rb"
  - "app/services/llm/**"
  - "app/services/*_prompt_builder.rb"
  - "app/services/*_schema_validator.rb"
  - "app/services/review_selector.rb"
  - "app/jobs/report_job.rb"
  - "app/jobs/icp_extraction_job.rb"
  - "app/models/report.rb"
---

# LLM pipeline

Read `current-understanding.md` in the vault (see `CLAUDE.md`) before changing
prompts, review sampling, model choice, or anything that affects cost.

## Output shape lives in code

There are two LLM outputs, each with a prompt builder and a validator:

| Output | Prompt | Validator | Called from |
|---|---|---|---|
| Report | `LlmPromptBuilder` | `ReportSchemaValidator` | `ReportJob` |
| ICP | `IcpPromptBuilder` | `IcpSchemaValidator` | `IcpExtractionJob` |

The prompt and the validator are the schema. Change both together, and update the
views that render it.

## Rules

- Nothing from the LLM is saved before its validator passes.
- Every run creates a new `Report` (`report_type`: `generate`, `refresh`, `reanalyze`).
  Reports are never updated in place with new output.
- Run metadata — review counts, token usage, cost, model, timing — goes in the `reports`
  columns, not inside `structured_output`. See `db/schema.rb`.
- Provider calls go through `LlmService`, never straight to an adapter in `app/services/llm/`.
