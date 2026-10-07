# frozen_string_literal: true

require "rails_helper"

RSpec.describe Llm::GeminiAdapter do
  subject(:adapter) { described_class.new }

  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:connection) do
    Faraday.new do |f|
      f.request :json
      f.response :json
      f.adapter :test, stubs
    end
  end

  let(:prompt) { "stubbed prompt" }
  let(:schema) { LlmService::GEMINI_RESPONSE_SCHEMA }
  let(:success_output) do
    { "summary" => "Users love the app but complain about crashes.", "pain_points" => [] }
  end

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("GEMINI_API_KEY").and_return("test-key")
    allow(Faraday).to receive(:new).and_return(connection)
    # Retry-path specs would otherwise sleep for real (2s + 4s per exhausted retry loop).
    allow(adapter).to receive(:sleep)
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

  def generate
    adapter.generate(prompt: prompt, schema: schema)
  end

  describe "#generate — happy path" do
    context "when the response text is wrapped in ```json fences" do
      before do
        text = "```json\n#{success_output.to_json}\n```"
        stubs.post("") { [ 200, { "Content-Type" => "application/json" }, gemini_response(text) ] }
      end

      it "returns a Result whose data is the parsed JSON" do
        expect(generate.data).to eq(success_output)
      end
    end

    context "when the response text is wrapped in bare ``` fences" do
      before do
        text = "```\n#{success_output.to_json}\n```"
        stubs.post("") { [ 200, { "Content-Type" => "application/json" }, gemini_response(text) ] }
      end

      it "returns a Result whose data is the parsed JSON" do
        expect(generate.data).to eq(success_output)
      end
    end

    context "when the response text has no fences at all" do
      before { stubs.post("") { success_response } }

      it "returns a Result whose data is the parsed JSON" do
        expect(generate.data).to eq(success_output)
      end

      it "returns a Result instance" do
        expect(generate).to be_a(LlmService::Result)
      end

      it "returns a Result whose usage equals the response's usageMetadata" do
        usage = { "promptTokenCount" => 100, "candidatesTokenCount" => 50, "thoughtsTokenCount" => 0 }
        expect(generate.usage).to eq(usage)
      end
    end

    context "when the response is missing usageMetadata entirely" do
      before do
        body = gemini_response(success_output.to_json)
        body.delete("usageMetadata")
        stubs.post("") { [ 200, { "Content-Type" => "application/json" }, body ] }
      end

      it "returns a Result whose usage is an empty Hash" do
        expect(generate.usage).to eq({})
      end
    end

    context "when the extracted text is not valid JSON" do
      before do
        text = "```json\nThis is not JSON, sorry.\n```"
        stubs.post("") { [ 200, { "Content-Type" => "application/json" }, gemini_response(text) ] }
      end

      it "raises LlmService::Error" do
        expect { generate }.to raise_error(LlmService::Error, /Invalid JSON response/)
      end
    end

    context "when the response is missing the expected candidates/content/parts/text structure" do
      before do
        stubs.post("") { [ 200, { "Content-Type" => "application/json" }, { "candidates" => [] } ] }
      end

      it "raises LlmService::Error mentioning the unexpected structure" do
        expect { generate }.to raise_error(LlmService::Error, /Unexpected response structure/)
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

      generate

      config = captured_body["generationConfig"]
      expect(config["response_mime_type"]).to eq("application/json")
      expect(config["max_output_tokens"]).to eq(16_000)
      expect(config["thinking_config"]).to eq({ "thinking_budget" => 0 })
      expect(config["response_schema"]).to eq(JSON.parse(LlmService::GEMINI_RESPONSE_SCHEMA.to_json))
    end
  end

  describe "#generate with the ICP schema" do
    let(:schema) { LlmService::ICP_RESPONSE_SCHEMA }
    let(:prompt) { "stubbed icp prompt" }
    let(:icp_output) do
      { "primary_segment" => "restaurant managers", "confidence" => "high", "signals" => [], "declined_reason" => nil }
    end

    it "sends ICP_RESPONSE_SCHEMA (not GEMINI_RESPONSE_SCHEMA) as response_schema" do
      captured_body = nil
      stubs.post("") do |env|
        captured_body = JSON.parse(env.body)
        [ 200, { "Content-Type" => "application/json" }, gemini_response(icp_output.to_json) ]
      end

      generate

      expect(captured_body["generationConfig"]["response_schema"]).to eq(JSON.parse(LlmService::ICP_RESPONSE_SCHEMA.to_json))
    end

    it "sends the given prompt as the request text" do
      captured_body = nil
      stubs.post("") do |env|
        captured_body = JSON.parse(env.body)
        [ 200, { "Content-Type" => "application/json" }, gemini_response(icp_output.to_json) ]
      end

      generate

      expect(captured_body.dig("contents", 0, "parts", 0, "text")).to eq("stubbed icp prompt")
    end

    it "returns a Result whose data is the parsed JSON" do
      stubs.post("") { [ 200, { "Content-Type" => "application/json" }, gemini_response(icp_output.to_json) ] }

      expect(generate.data).to eq(icp_output)
    end

    it "returns a Result instance" do
      stubs.post("") { [ 200, { "Content-Type" => "application/json" }, gemini_response(icp_output.to_json) ] }

      expect(generate).to be_a(LlmService::Result)
    end

    it "strips ```json fences from the response text" do
      text = "```json\n#{icp_output.to_json}\n```"
      stubs.post("") { [ 200, { "Content-Type" => "application/json" }, gemini_response(text) ] }

      expect(generate.data).to eq(icp_output)
    end

    it "raises LlmService::TruncatedResponseError on MAX_TOKENS" do
      stubs.post("") { [ 200, { "Content-Type" => "application/json" }, gemini_response("not { valid json", finish_reason: "MAX_TOKENS") ] }

      expect { generate }.to raise_error(LlmService::TruncatedResponseError)
    end

    it "retries on a 503 up to MAX_ATTEMPTS and raises LlmService::Error" do
      call_count = 0
      stubs.post("") do
        call_count += 1
        [ 503, {}, "Service Unavailable" ]
      end

      expect { generate }.to raise_error(LlmService::Error, /HTTP 503/)
      expect(call_count).to eq(3)
    end
  end

  describe "timeout configuration" do
    it "sets OPEN_TIMEOUT_SECONDS to 10" do
      expect(described_class::OPEN_TIMEOUT_SECONDS).to eq(10)
    end

    it "sets READ_TIMEOUT_SECONDS to 180" do
      expect(described_class::READ_TIMEOUT_SECONDS).to eq(180)
    end

    it "configures the real Faraday connection with the open and read timeouts" do
      allow(Faraday).to receive(:new).and_call_original

      real_connection = adapter.send(:connection)

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

      expect { generate }.to raise_error(LlmService::TruncatedResponseError)
    end

    it "does not call JSON.parse" do
      stubs.post("") { max_tokens_response }
      expect(JSON).not_to receive(:parse)

      expect { generate }.to raise_error(LlmService::TruncatedResponseError)
    end

    it "does not retry" do
      call_count = 0
      stubs.post("") do
        call_count += 1
        max_tokens_response
      end

      expect { generate }.to raise_error(LlmService::TruncatedResponseError)
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

        expect { generate }.to raise_error(LlmService::Error, /HTTP 503/)
        expect(call_count).to eq(described_class::MAX_ATTEMPTS)
      end

      it "sleeps with exponential backoff between attempts" do
        stubs.post("") { [ 503, {}, "Service Unavailable" ] }

        begin
          generate
        rescue LlmService::Error
          nil
        end

        expect(adapter).to have_received(:sleep).with(2).ordered
        expect(adapter).to have_received(:sleep).with(4).ordered
        expect(adapter).to have_received(:sleep).twice
      end

      it "returns the successful result once a later attempt succeeds" do
        call_count = 0
        stubs.post("") do
          call_count += 1
          call_count < 3 ? [ 503, {}, "Service Unavailable" ] : success_response
        end

        expect(generate.data).to eq(success_output)
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

        expect { generate }.to raise_error(LlmService::Error, /HTTP 429/)
        expect(call_count).to eq(described_class::MAX_ATTEMPTS)
      end
    end

    context "on Faraday::TimeoutError" do
      it "retries up to MAX_ATTEMPTS times and raises LlmService::Error mentioning the timeout" do
        call_count = 0
        stubs.post("") do
          call_count += 1
          raise Faraday::TimeoutError, "execution expired"
        end

        expect { generate }.to raise_error(LlmService::Error, /timed out/)
        expect(call_count).to eq(described_class::MAX_ATTEMPTS)
      end

      it "sleeps with exponential backoff between attempts" do
        stubs.post("") { raise Faraday::TimeoutError, "execution expired" }

        begin
          generate
        rescue LlmService::Error
          nil
        end

        expect(adapter).to have_received(:sleep).with(2).ordered
        expect(adapter).to have_received(:sleep).with(4).ordered
      end
    end

    context "on a non-retryable 4xx error" do
      it "does not retry" do
        call_count = 0
        stubs.post("") do
          call_count += 1
          [ 400, {}, "Bad Request" ]
        end

        expect { generate }.to raise_error(LlmService::Error, /HTTP 400/)
        expect(call_count).to eq(1)
      end

      it "does not sleep" do
        stubs.post("") { [ 400, {}, "Bad Request" ] }

        begin
          generate
        rescue LlmService::Error
          nil
        end

        expect(adapter).not_to have_received(:sleep)
      end
    end
  end

  describe "token usage logging" do
    it "logs the prompt, candidate, and thinking token counts on a successful response" do
      stubs.post("") { success_response }

      expect(Rails.logger).to receive(:info).with(/input: 100, output: 50, thinking: 0/)

      generate
    end
  end

  describe "MODEL / GEMINI_URL" do
    it "builds the GEMINI_URL from LlmService::MODEL" do
      expect(described_class::GEMINI_URL).to include(LlmService::MODEL)
    end
  end
end
