# frozen_string_literal: true

class LlmService
  Error = Class.new(StandardError)
  TruncatedResponseError = Class.new(StandardError)

  Result = Struct.new(:data, :usage, keyword_init: true)

  OPEN_TIMEOUT_SECONDS = 10
  READ_TIMEOUT_SECONDS = 180

  MAX_ATTEMPTS = 3
  RETRYABLE_STATUSES = [ 429, 503 ].freeze

  MODEL = "gemini-2.5-flash"

  GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/models/#{MODEL}:generateContent"

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
    generate(prompt: prompt, schema: GEMINI_RESPONSE_SCHEMA)
  end

  def self.extract_icp(reviews:)
    prompt = IcpPromptBuilder.build(reviews: reviews)
    generate(prompt: prompt, schema: ICP_RESPONSE_SCHEMA)
  end

  def self.generate(prompt:, schema:)
    response = request_with_retries(prompt, schema)

    raise Error, "HTTP #{response.status}" unless response.success?

    body = response.body

    log_token_usage(body)

    finish_reason = body.dig("candidates", 0, "finishReason")
    if finish_reason == "MAX_TOKENS"
      raise TruncatedResponseError, "Gemini hit max_output_tokens before finishing the response. Consider raising max_output_tokens or tightening the prompt."
    end

    text = body.dig("candidates", 0, "content", "parts", 0, "text")
    raise Error, "Unexpected response structure: #{body.inspect}" if text.nil?

    data = JSON.parse(strip_code_fences(text))
    Result.new(data: data, usage: body["usageMetadata"] || {})
  rescue Faraday::Error => e
    raise Error, e.message
  rescue JSON::ParserError => e
    raise Error, "Invalid JSON response: #{e.message}"
  end

  def self.cost_usd(model:, input_tokens:, output_tokens:)
    rates = RATES_USD_PER_MILLION_TOKENS.fetch(model)
    (input_tokens.to_f * rates[:input] + output_tokens.to_f * rates[:output]) / 1_000_000.0
  end

  def self.request_with_retries(prompt, schema)
    response = nil

    MAX_ATTEMPTS.times do |attempt|
      last_attempt = attempt == MAX_ATTEMPTS - 1

      begin
        response = make_request(prompt, schema)
      rescue Faraday::TimeoutError => e
        raise Error, "Request timed out: #{e.message}" if last_attempt

        sleep(2**(attempt + 1))
        next
      end

      break if response.success?
      break unless RETRYABLE_STATUSES.include?(response.status)
      break if last_attempt

      sleep(2**(attempt + 1))
    end

    response
  end

  def self.make_request(prompt, schema)
    connection.post("") do |req|
      req.params["key"] = ENV.fetch("GEMINI_API_KEY")
      req.body = {
        contents: [
          { parts: [ { text: prompt } ] }
        ],
        generationConfig: {
          response_mime_type: "application/json",
          response_schema: schema,
          max_output_tokens: 16_000,
          thinking_config: { thinking_budget: 0 }
        }
      }
    end
  end

  def self.connection
    Faraday.new(url: GEMINI_URL) do |f|
      f.options.open_timeout = OPEN_TIMEOUT_SECONDS
      f.options.timeout = READ_TIMEOUT_SECONDS
      f.request :json
      f.response :json
    end
  end

  def self.log_token_usage(body)
    usage = body["usageMetadata"]
    Rails.logger.info("[LlmService] tokens — input: #{usage&.dig('promptTokenCount')}, output: #{usage&.dig('candidatesTokenCount')}, thinking: #{usage&.dig('thoughtsTokenCount')}")
  end

  def self.strip_code_fences(text)
    text.to_s.strip.sub(/\A```(?:json)?\s*\n?/, "").sub(/\n?```\z/, "").strip
  end

  private_class_method :generate, :request_with_retries, :make_request, :connection, :log_token_usage, :strip_code_fences
end
