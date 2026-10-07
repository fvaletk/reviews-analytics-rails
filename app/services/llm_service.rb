# frozen_string_literal: true

class LlmService
  Error = Class.new(StandardError)
  TruncatedResponseError = Class.new(StandardError)

  Result = Struct.new(:data, :usage, keyword_init: true)

  MODEL = "gemini-2.5-flash"

  # USD per 1,000,000 tokens. Source: https://ai.google.dev/gemini-api/docs/pricing (gemini-2.5-flash, paid tier, text/image/video input).
  # Thinking tokens are billed at the output rate — Google does not price them separately.
  RATES_USD_PER_MILLION_TOKENS = {
    "gemini-2.5-flash" => { input: 0.30, output: 2.50 }
  }.freeze

  GEMINI_RESPONSE_SCHEMA = {
    type: "OBJECT",
    properties: {
      summary: { type: "STRING" },
      pain_points: {
        type: "ARRAY",
        items: {
          type: "OBJECT",
          required: [ "title", "severity", "frequency", "description", "evidence_count" ],
          properties: {
            title: { type: "STRING" },
            severity: { type: "STRING", enum: [ "critical", "high", "medium", "low" ] },
            frequency: { type: "STRING", enum: [ "high", "medium", "low" ] },
            description: { type: "STRING" },
            evidence_count: { type: "INTEGER" }
          }
        }
      },
      complaints: {
        type: "ARRAY",
        items: {
          type: "OBJECT",
          required: [ "title", "description", "frequency" ],
          properties: {
            title: { type: "STRING" },
            description: { type: "STRING" },
            frequency: { type: "STRING", enum: [ "high", "medium", "low" ] }
          }
        }
      },
      feature_requests: {
        type: "ARRAY",
        items: {
          type: "OBJECT",
          required: [ "category", "items" ],
          properties: {
            category: { type: "STRING" },
            items: {
              type: "ARRAY",
              items: {
                type: "OBJECT",
                required: [ "title", "description", "demand" ],
                properties: {
                  title: { type: "STRING" },
                  description: { type: "STRING" },
                  demand: { type: "STRING", enum: [ "high", "medium", "low" ] }
                }
              }
            }
          }
        }
      },
      strengths: {
        type: "ARRAY",
        items: {
          type: "OBJECT",
          required: [ "title", "description" ],
          properties: {
            title: { type: "STRING" },
            description: { type: "STRING" }
          }
        }
      },
      opportunities: {
        type: "ARRAY",
        items: {
          type: "OBJECT",
          required: [ "title", "description", "rationale" ],
          properties: {
            title: { type: "STRING" },
            description: { type: "STRING" },
            rationale: { type: "STRING" }
          }
        }
      }
    },
    required: [ "summary", "pain_points", "complaints", "feature_requests", "strengths", "opportunities" ]
  }.freeze

  ICP_RESPONSE_SCHEMA = {
    type: "OBJECT",
    properties: {
      primary_segment: { type: "STRING", nullable: true },
      confidence:      { type: "STRING", enum: [ "high", "medium", "low" ], nullable: true },
      signals: {
        type: "ARRAY",
        items: {
          type: "OBJECT",
          required: [ "quote", "role_hint" ],
          properties: {
            quote:     { type: "STRING" },
            role_hint: { type: "STRING" }
          }
        }
      },
      declined_reason: { type: "STRING", nullable: true }
    },
    required: [ "primary_segment", "confidence", "signals", "declined_reason" ]
  }.freeze

  def self.analyze(reviews:, distribution:)
    prompt = LlmPromptBuilder.build(reviews: reviews, distribution: distribution)
    adapter.generate(prompt: prompt, schema: GEMINI_RESPONSE_SCHEMA)
  end

  def self.extract_icp(reviews:)
    prompt = IcpPromptBuilder.build(reviews: reviews)
    adapter.generate(prompt: prompt, schema: ICP_RESPONSE_SCHEMA)
  end

  def self.adapter
    Llm::GeminiAdapter.new
  end

  def self.cost_usd(model:, input_tokens:, output_tokens:)
    rates = RATES_USD_PER_MILLION_TOKENS.fetch(model)
    (input_tokens.to_f * rates[:input] + output_tokens.to_f * rates[:output]) / 1_000_000.0
  end
end
