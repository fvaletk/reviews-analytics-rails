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
  let(:parsed_output) do
    {
      "summary" => "Users love the app but complain about crashes.",
      "pain_points" => []
    }
  end

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("GEMINI_API_KEY").and_return("test-key")
    allow(Faraday).to receive(:new).and_return(connection)
    allow(LlmPromptBuilder).to receive(:build).with(reviews: reviews).and_return("stubbed prompt")
  end

  def gemini_response(text)
    {
      "candidates" => [
        { "content" => { "parts" => [ { "text" => text } ] } }
      ]
    }
  end

  describe ".analyze" do
    context "when the response text is wrapped in ```json fences" do
      before do
        text = "```json\n#{parsed_output.to_json}\n```"
        stubs.post("") { [ 200, { "Content-Type" => "application/json" }, gemini_response(text) ] }
      end

      it "returns the parsed JSON as a Hash" do
        expect(described_class.analyze(reviews: reviews)).to eq(parsed_output)
      end
    end

    context "when the response text is wrapped in bare ``` fences" do
      before do
        text = "```\n#{parsed_output.to_json}\n```"
        stubs.post("") { [ 200, { "Content-Type" => "application/json" }, gemini_response(text) ] }
      end

      it "returns the parsed JSON as a Hash" do
        expect(described_class.analyze(reviews: reviews)).to eq(parsed_output)
      end
    end

    context "when the response text has no fences at all" do
      before do
        text = parsed_output.to_json
        stubs.post("") { [ 200, { "Content-Type" => "application/json" }, gemini_response(text) ] }
      end

      it "returns the parsed JSON as a Hash" do
        expect(described_class.analyze(reviews: reviews)).to eq(parsed_output)
      end
    end

    context "when the extracted text is not valid JSON" do
      before do
        text = "```json\nThis is not JSON, sorry.\n```"
        stubs.post("") { [ 200, { "Content-Type" => "application/json" }, gemini_response(text) ] }
      end

      it "raises LlmService::Error" do
        expect { described_class.analyze(reviews: reviews) }.to raise_error(LlmService::Error, /Invalid JSON response/)
      end
    end

    context "when the API returns a non-success HTTP status" do
      before do
        stubs.post("") { [ 500, {}, "Internal Server Error" ] }
      end

      it "raises LlmService::Error with the status code" do
        expect { described_class.analyze(reviews: reviews) }.to raise_error(LlmService::Error, /HTTP 500/)
      end
    end

    context "when the request times out" do
      before do
        stubs.post("") { raise Faraday::TimeoutError, "execution expired" }
      end

      it "raises LlmService::Error mentioning the timeout" do
        expect { described_class.analyze(reviews: reviews) }.to raise_error(LlmService::Error, /timed out/)
      end
    end

    context "when the response is missing the expected candidates/content/parts/text structure" do
      before do
        stubs.post("") { [ 200, { "Content-Type" => "application/json" }, { "candidates" => [] } ] }
      end

      it "raises LlmService::Error mentioning the unexpected structure" do
        expect { described_class.analyze(reviews: reviews) }.to raise_error(LlmService::Error, /Unexpected response structure/)
      end
    end
  end

  describe "LlmService::Error" do
    it "is a subclass of StandardError" do
      expect(LlmService::Error.ancestors).to include(StandardError)
    end
  end

  describe "timeout configuration" do
    it "sets a 60 second timeout constant" do
      expect(LlmService::TIMEOUT_SECONDS).to eq(60)
    end
  end
end
