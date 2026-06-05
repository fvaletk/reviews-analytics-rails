# Skill: report-schema

## Overview

The LLM returns a single JSON object. It is validated with `ReportSchemaValidator`
before being saved to `reports.structured_output` (JSONB column).

Never save unvalidated LLM output to the database.

## Full Schema

```json
{
  "summary": "string — 2-3 sentence executive summary",

  "pain_points": [
    {
      "title": "string",
      "severity": "critical | high | medium | low",
      "frequency": "high | medium | low",
      "description": "string",
      "evidence_count": 0
    }
  ],

  "complaints": [
    {
      "title": "string",
      "description": "string",
      "frequency": "high | medium | low"
    }
  ],

  "feature_requests": [
    {
      "category": "string",
      "items": [
        {
          "title": "string",
          "description": "string",
          "demand": "high | medium | low"
        }
      ]
    }
  ],

  "strengths": [
    {
      "title": "string",
      "description": "string"
    }
  ],

  "opportunities": [
    {
      "title": "string",
      "description": "string",
      "rationale": "string"
    }
  ]
}
```

## Severity / Frequency / Demand Values

These are the only valid values. Validator rejects anything else.

- `severity`: `critical`, `high`, `medium`, `low`
- `frequency`: `high`, `medium`, `low`
- `demand`: `high`, `medium`, `low`

## Prompt Rules

When building the LLM prompt in `LlmPromptBuilder`:

1. Serialize reviews as compact array: `[{ store, rating, title, body }]`
   — omit `author` and `reviewed_at` to reduce token count
2. Embed the schema above inline in the prompt
3. End the prompt with: `"Return only valid JSON matching the schema above. No markdown. No explanation. No preamble."`

## Validation Rules (`ReportSchemaValidator`)

Raise `ReportSchemaValidator::InvalidSchema` if:
- Any top-level key is missing
- Any top-level array is not an Array
- Any `pain_points` item is missing `title`, `severity`, `frequency`, or `description`
- `severity` is not one of the four valid values

## Report Metadata

The following fields are stored separately on the `reports` record
(not inside `structured_output`):

- `total_reviews_analyzed` — set after reviews are saved, before LLM call
- `reviews_fetched_at` — timestamp when scraping completed
- `generated_by_user_id` — user who triggered the job
- `status` — pipeline status enum

## Re-generation Modes

| Mode | Scraping | LLM |
|---|---|---|
| Generate (first time) | ✅ calls FastAPI | ✅ |
| Refresh reviews + re-analyze | ✅ calls FastAPI | ✅ |
| Re-analyze only | ❌ uses stored reviews | ✅ |

All three modes create a **new Report record**. Old reports are never overwritten.