# frozen_string_literal: true

class LlmService
  Error = Class.new(StandardError)

  TIMEOUT_SECONDS = 60
  GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent"

  def self.analyze(reviews:)
    prompt = LlmPromptBuilder.build(reviews: reviews)

    connection = Faraday.new(url: GEMINI_URL) do |f|
      f.options.timeout = TIMEOUT_SECONDS
      f.options.open_timeout = TIMEOUT_SECONDS
      f.request :json
      f.response :json
    end

    response = connection.post("") do |req|
      req.params["key"] = ENV.fetch("GEMINI_API_KEY")
      req.body = {
        contents: [
          { parts: [ { text: prompt } ] }
        ]
      }
    end

    raise Error, "HTTP #{response.status}" unless response.success?

    text = response.body.dig("candidates", 0, "content", "parts", 0, "text")
    raise Error, "Unexpected response structure: #{response.body.inspect}" if text.nil?

    JSON.parse(strip_code_fences(text))
  rescue Faraday::TimeoutError => e
    raise Error, "Request timed out: #{e.message}"
  rescue Faraday::Error => e
    raise Error, e.message
  rescue JSON::ParserError => e
    raise Error, "Invalid JSON response: #{e.message}"
  end

  def self.strip_code_fences(text)
    text.to_s.strip.sub(/\A```(?:json)?\s*\n?/, "").sub(/\n?```\z/, "").strip
  end
  private_class_method :strip_code_fences
end
