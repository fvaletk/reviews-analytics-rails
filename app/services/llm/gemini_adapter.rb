# frozen_string_literal: true

module Llm
  class GeminiAdapter
    OPEN_TIMEOUT_SECONDS = 10
    READ_TIMEOUT_SECONDS = 180

    MAX_ATTEMPTS = 3
    RETRYABLE_STATUSES = [ 429, 503 ].freeze

    GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/models/#{LlmService::MODEL}:generateContent"

    def generate(prompt:, schema:)
      response = request_with_retries(prompt, schema)

      raise LlmService::Error, "HTTP #{response.status}" unless response.success?

      body = response.body

      log_token_usage(body)

      finish_reason = body.dig("candidates", 0, "finishReason")
      if finish_reason == "MAX_TOKENS"
        raise LlmService::TruncatedResponseError, "Gemini hit max_output_tokens before finishing the response. Consider raising max_output_tokens or tightening the prompt."
      end

      text = body.dig("candidates", 0, "content", "parts", 0, "text")
      raise LlmService::Error, "Unexpected response structure: #{body.inspect}" if text.nil?

      data = JSON.parse(strip_code_fences(text))
      LlmService::Result.new(data: data, usage: body["usageMetadata"] || {})
    rescue Faraday::Error => e
      raise LlmService::Error, e.message
    rescue JSON::ParserError => e
      raise LlmService::Error, "Invalid JSON response: #{e.message}"
    end

    private

    def request_with_retries(prompt, schema)
      response = nil

      MAX_ATTEMPTS.times do |attempt|
        last_attempt = attempt == MAX_ATTEMPTS - 1

        begin
          response = make_request(prompt, schema)
        rescue Faraday::TimeoutError => e
          raise LlmService::Error, "Request timed out: #{e.message}" if last_attempt

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

    def make_request(prompt, schema)
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

    def connection
      Faraday.new(url: GEMINI_URL) do |f|
        f.options.open_timeout = OPEN_TIMEOUT_SECONDS
        f.options.timeout = READ_TIMEOUT_SECONDS
        f.request :json
        f.response :json
      end
    end

    def log_token_usage(body)
      usage = body["usageMetadata"]
      Rails.logger.info("[LlmService] tokens — input: #{usage&.dig('promptTokenCount')}, output: #{usage&.dig('candidatesTokenCount')}, thinking: #{usage&.dig('thoughtsTokenCount')}")
    end

    def strip_code_fences(text)
      text.to_s.strip.sub(/\A```(?:json)?\s*\n?/, "").sub(/\n?```\z/, "").strip
    end
  end
end
