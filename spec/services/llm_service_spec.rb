# frozen_string_literal: true

require "rails_helper"

RSpec.describe LlmService do
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:connection) do
    Faraday.new do |f|
      f.request :json
      f.response :json
      f.adapter :test, stubs
    end
  end

  let(:reviews) { [] }
  let(:distribution) { { "1" => 0, "2" => 0, "3" => 0, "4" => 0, "5" => 0, "unrated" => 0 } }
  let(:success_output) do
    { "summary" => "Users love the app but complain about crashes.", "pain_points" => [] }
  end

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("GEMINI_API_KEY").and_return("test-key")
    allow(Faraday).to receive(:new).and_return(connection)
    allow(LlmPromptBuilder).to receive(:build).with(reviews: reviews, distribution: distribution).and_return("stubbed prompt")
    # Retry-path specs would otherwise sleep for real (2s + 4s per exhausted retry loop).
    allow(described_class).to receive(:sleep)
  end

  def gemini_response(text, finish_reason: "STOP", usage: { "promptTokenCount" => 100, "candidatesTokenCount" => 50, "thoughtsTokenCount" => 0 })
    {
      "candidates" => [
        { "content" => { "parts" => [ { "text" => text } ] }, "finishReason" => finish_reason }
      ],
      "usageMetadata" => usage
    }
  end

  def success_response(body = success_output, **opts)
    [ 200, { "Content-Type" => "application/json" }, gemini_response(body.to_json, **opts) ]
  end

  describe ".analyze — happy path" do
    context "forwarding to LlmPromptBuilder" do
      before { stubs.post("") { success_response } }

      it "forwards reviews: and distribution: to LlmPromptBuilder.build" do
        described_class.analyze(reviews: reviews, distribution: distribution)

        expect(LlmPromptBuilder).to have_received(:build).with(reviews: reviews, distribution: distribution)
      end
    end

    context "when the response text is wrapped in ```json fences" do
      before do
        text = "```json\n#{success_output.to_json}\n```"
        stubs.post("") { [ 200, { "Content-Type" => "application/json" }, gemini_response(text) ] }
      end

      it "returns a Result whose data is the parsed JSON" do
        expect(described_class.analyze(reviews: reviews, distribution: distribution).data).to eq(success_output)
      end
    end

    context "when the response text is wrapped in bare ``` fences" do
      before do
        text = "```\n#{success_output.to_json}\n```"
        stubs.post("") { [ 200, { "Content-Type" => "application/json" }, gemini_response(text) ] }
      end

      it "returns a Result whose data is the parsed JSON" do
        expect(described_class.analyze(reviews: reviews, distribution: distribution).data).to eq(success_output)
      end
    end

    context "when the response text has no fences at all" do
      before { stubs.post("") { success_response } }

      it "returns a Result whose data is the parsed JSON" do
        expect(described_class.analyze(reviews: reviews, distribution: distribution).data).to eq(success_output)
      end

      it "returns a Result instance" do
        expect(described_class.analyze(reviews: reviews, distribution: distribution)).to be_a(LlmService::Result)
      end

      it "returns a Result whose usage equals the response's usageMetadata" do
        usage = { "promptTokenCount" => 100, "candidatesTokenCount" => 50, "thoughtsTokenCount" => 0 }
        expect(described_class.analyze(reviews: reviews, distribution: distribution).usage).to eq(usage)
      end
    end

    context "when the response is missing usageMetadata entirely" do
      before do
        body = gemini_response(success_output.to_json)
        body.delete("usageMetadata")
        stubs.post("") { [ 200, { "Content-Type" => "application/json" }, body ] }
      end

      it "returns a Result whose usage is an empty Hash" do
        expect(described_class.analyze(reviews: reviews, distribution: distribution).usage).to eq({})
      end
    end

    context "when the extracted text is not valid JSON" do
      before do
        text = "```json\nThis is not JSON, sorry.\n```"
        stubs.post("") { [ 200, { "Content-Type" => "application/json" }, gemini_response(text) ] }
      end

      it "raises LlmService::Error" do
        expect { described_class.analyze(reviews: reviews, distribution: distribution) }.to raise_error(LlmService::Error, /Invalid JSON response/)
      end
    end

    context "when the response is missing the expected candidates/content/parts/text structure" do
      before do
        stubs.post("") { [ 200, { "Content-Type" => "application/json" }, { "candidates" => [] } ] }
      end

      it "raises LlmService::Error mentioning the unexpected structure" do
        expect { described_class.analyze(reviews: reviews, distribution: distribution) }.to raise_error(LlmService::Error, /Unexpected response structure/)
      end
    end
  end

  describe "generationConfig sent in the request body" do
    it "includes response_mime_type, the full response_schema, max_output_tokens, and thinking_budget" do
      captured_body = nil
      stubs.post("") do |env|
        captured_body = JSON.parse(env.body)
        success_response
      end

      described_class.analyze(reviews: reviews, distribution: distribution)

      config = captured_body["generationConfig"]
      expect(config["response_mime_type"]).to eq("application/json")
      expect(config["max_output_tokens"]).to eq(16_000)
      expect(config["thinking_config"]).to eq({ "thinking_budget" => 0 })
      expect(config["response_schema"]).to eq(JSON.parse(LlmService::GEMINI_RESPONSE_SCHEMA.to_json))
    end
  end

  describe "GEMINI_RESPONSE_SCHEMA enums — must match the report-schema contract exactly" do
    it "defines the severity enum for pain_points" do
      severity_enum = LlmService::GEMINI_RESPONSE_SCHEMA.dig(:properties, :pain_points, :items, :properties, :severity, :enum)
      expect(severity_enum).to eq(%w[critical high medium low])
    end

    it "defines the frequency enum for pain_points" do
      frequency_enum = LlmService::GEMINI_RESPONSE_SCHEMA.dig(:properties, :pain_points, :items, :properties, :frequency, :enum)
      expect(frequency_enum).to eq(%w[high medium low])
    end

    it "defines the frequency enum for complaints" do
      frequency_enum = LlmService::GEMINI_RESPONSE_SCHEMA.dig(:properties, :complaints, :items, :properties, :frequency, :enum)
      expect(frequency_enum).to eq(%w[high medium low])
    end

    it "defines the demand enum for feature_requests items" do
      demand_enum = LlmService::GEMINI_RESPONSE_SCHEMA.dig(:properties, :feature_requests, :items, :properties, :items, :items, :properties, :demand, :enum)
      expect(demand_enum).to eq(%w[high medium low])
    end
  end

  describe "timeout configuration" do
    it "sets OPEN_TIMEOUT_SECONDS to 10" do
      expect(LlmService::OPEN_TIMEOUT_SECONDS).to eq(10)
    end

    it "sets READ_TIMEOUT_SECONDS to 180" do
      expect(LlmService::READ_TIMEOUT_SECONDS).to eq(180)
    end

    it "configures the real Faraday connection with the open and read timeouts" do
      allow(Faraday).to receive(:new).and_call_original

      real_connection = described_class.send(:connection)

      expect(real_connection.options.open_timeout).to eq(10)
      expect(real_connection.options.timeout).to eq(180)
    end
  end

  describe "MAX_TOKENS handling" do
    def max_tokens_response
      [ 200, { "Content-Type" => "application/json" }, gemini_response("not { valid json", finish_reason: "MAX_TOKENS") ]
    end

    it "raises LlmService::TruncatedResponseError" do
      stubs.post("") { max_tokens_response }

      expect { described_class.analyze(reviews: reviews, distribution: distribution) }.to raise_error(LlmService::TruncatedResponseError)
    end

    it "does not call JSON.parse" do
      stubs.post("") { max_tokens_response }
      expect(JSON).not_to receive(:parse)

      expect { described_class.analyze(reviews: reviews, distribution: distribution) }.to raise_error(LlmService::TruncatedResponseError)
    end

    it "does not retry" do
      call_count = 0
      stubs.post("") do
        call_count += 1
        max_tokens_response
      end

      expect { described_class.analyze(reviews: reviews, distribution: distribution) }.to raise_error(LlmService::TruncatedResponseError)
      expect(call_count).to eq(1)
    end
  end

  describe "retry behavior" do
    context "on 503 Service Unavailable" do
      it "retries up to MAX_ATTEMPTS times and raises LlmService::Error if still failing" do
        call_count = 0
        stubs.post("") do
          call_count += 1
          [ 503, {}, "Service Unavailable" ]
        end

        expect { described_class.analyze(reviews: reviews, distribution: distribution) }.to raise_error(LlmService::Error, /HTTP 503/)
        expect(call_count).to eq(3)
      end

      it "sleeps with exponential backoff between attempts" do
        stubs.post("") { [ 503, {}, "Service Unavailable" ] }

        begin
          described_class.analyze(reviews: reviews, distribution: distribution)
        rescue LlmService::Error
          nil
        end

        expect(described_class).to have_received(:sleep).with(2).ordered
        expect(described_class).to have_received(:sleep).with(4).ordered
        expect(described_class).to have_received(:sleep).twice
      end

      it "returns the successful result once a later attempt succeeds" do
        call_count = 0
        stubs.post("") do
          call_count += 1
          call_count < 3 ? [ 503, {}, "Service Unavailable" ] : success_response
        end

        expect(described_class.analyze(reviews: reviews, distribution: distribution).data).to eq(success_output)
        expect(call_count).to eq(3)
      end
    end

    context "on 429 Too Many Requests" do
      it "retries up to MAX_ATTEMPTS times and raises LlmService::Error if still failing" do
        call_count = 0
        stubs.post("") do
          call_count += 1
          [ 429, {}, "Too Many Requests" ]
        end

        expect { described_class.analyze(reviews: reviews, distribution: distribution) }.to raise_error(LlmService::Error, /HTTP 429/)
        expect(call_count).to eq(3)
      end
    end

    context "on Faraday::TimeoutError" do
      it "retries up to MAX_ATTEMPTS times and raises LlmService::Error mentioning the timeout" do
        call_count = 0
        stubs.post("") do
          call_count += 1
          raise Faraday::TimeoutError, "execution expired"
        end

        expect { described_class.analyze(reviews: reviews, distribution: distribution) }.to raise_error(LlmService::Error, /timed out/)
        expect(call_count).to eq(3)
      end

      it "sleeps with exponential backoff between attempts" do
        stubs.post("") { raise Faraday::TimeoutError, "execution expired" }

        begin
          described_class.analyze(reviews: reviews, distribution: distribution)
        rescue LlmService::Error
          nil
        end

        expect(described_class).to have_received(:sleep).with(2).ordered
        expect(described_class).to have_received(:sleep).with(4).ordered
      end
    end

    context "on a non-retryable 4xx error" do
      it "does not retry" do
        call_count = 0
        stubs.post("") do
          call_count += 1
          [ 400, {}, "Bad Request" ]
        end

        expect { described_class.analyze(reviews: reviews, distribution: distribution) }.to raise_error(LlmService::Error, /HTTP 400/)
        expect(call_count).to eq(1)
      end

      it "does not sleep" do
        stubs.post("") { [ 400, {}, "Bad Request" ] }

        begin
          described_class.analyze(reviews: reviews, distribution: distribution)
        rescue LlmService::Error
          nil
        end

        expect(described_class).not_to have_received(:sleep)
      end
    end
  end

  describe "token usage logging" do
    it "logs the prompt, candidate, and thinking token counts on a successful response" do
      stubs.post("") { success_response }

      expect(Rails.logger).to receive(:info).with(/input: 100, output: 50, thinking: 0/)

      described_class.analyze(reviews: reviews, distribution: distribution)
    end
  end

  describe ".cost_usd" do
    context "with a known model" do
      let(:model) { LlmService::MODEL }
      let(:rates) { LlmService::RATES_USD_PER_MILLION_TOKENS.fetch(model) }

      it "computes the cost using the model's input and output rates per million tokens" do
        input_tokens = 123_456
        output_tokens = 78_901
        expected = (input_tokens * rates[:input] + output_tokens * rates[:output]) / 1_000_000.0

        result = described_class.cost_usd(model: model, input_tokens: input_tokens, output_tokens: output_tokens)

        expect(result).to eq(expected)
      end

      it "prices exactly 1,000,000 input tokens at the model's input rate" do
        result = described_class.cost_usd(model: model, input_tokens: 1_000_000, output_tokens: 0)

        expect(result).to eq(rates[:input])
      end

      it "prices exactly 1,000,000 output tokens at the model's output rate" do
        result = described_class.cost_usd(model: model, input_tokens: 0, output_tokens: 1_000_000)

        expect(result).to eq(rates[:output])
      end

      it "prices input and output tokens separately rather than at a single blended rate" do
        input_only = described_class.cost_usd(model: model, input_tokens: 1_000_000, output_tokens: 0)
        output_only = described_class.cost_usd(model: model, input_tokens: 0, output_tokens: 1_000_000)

        expect(input_only).not_to eq(output_only)
      end
    end

    context "with an unknown model" do
      it "raises KeyError" do
        expect {
          described_class.cost_usd(model: "not-a-real-model", input_tokens: 100, output_tokens: 100)
        }.to raise_error(KeyError)
      end
    end
  end

  describe "LlmService::MODEL" do
    it "is used to build the GEMINI_URL" do
      expect(LlmService::GEMINI_URL).to include(LlmService::MODEL)
    end
  end

  describe "LlmService::Error" do
    it "is a subclass of StandardError" do
      expect(LlmService::Error.ancestors).to include(StandardError)
    end
  end

  describe "LlmService::TruncatedResponseError" do
    it "is a subclass of StandardError" do
      expect(LlmService::TruncatedResponseError.ancestors).to include(StandardError)
    end
  end
end
