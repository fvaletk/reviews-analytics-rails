# frozen_string_literal: true

require "rails_helper"

RSpec.describe LlmService do
  let(:adapter) { instance_double(Llm::GeminiAdapter) }
  let(:reviews) { [] }
  let(:distribution) { { "1" => 0, "2" => 0, "3" => 0, "4" => 0, "5" => 0, "unrated" => 0 } }
  let(:result) { LlmService::Result.new(data: { "summary" => "ok" }, usage: { "promptTokenCount" => 1 }) }

  before { allow(described_class).to receive(:adapter).and_return(adapter) }

  describe ".analyze" do
    before do
      allow(LlmPromptBuilder).to receive(:build).with(reviews: reviews, distribution: distribution).and_return("stubbed prompt")
      allow(adapter).to receive(:generate).and_return(result)
    end

    it "forwards reviews: and distribution: to LlmPromptBuilder.build" do
      described_class.analyze(reviews: reviews, distribution: distribution)

      expect(LlmPromptBuilder).to have_received(:build).with(reviews: reviews, distribution: distribution)
    end

    it "calls the adapter with the built prompt and GEMINI_RESPONSE_SCHEMA" do
      described_class.analyze(reviews: reviews, distribution: distribution)

      expect(adapter).to have_received(:generate).with(prompt: "stubbed prompt", schema: LlmService::GEMINI_RESPONSE_SCHEMA)
    end

    it "returns the adapter's Result" do
      expect(described_class.analyze(reviews: reviews, distribution: distribution)).to be(result)
    end

    it "propagates LlmService::Error from the adapter unchanged" do
      error = LlmService::Error.new("HTTP 503")
      allow(adapter).to receive(:generate).and_raise(error)

      expect { described_class.analyze(reviews: reviews, distribution: distribution) }.to raise_error(be(error))
    end

    it "propagates LlmService::TruncatedResponseError from the adapter unchanged" do
      error = LlmService::TruncatedResponseError.new("truncated")
      allow(adapter).to receive(:generate).and_raise(error)

      expect { described_class.analyze(reviews: reviews, distribution: distribution) }.to raise_error(be(error))
    end
  end

  describe ".extract_icp" do
    before do
      allow(IcpPromptBuilder).to receive(:build).with(reviews: reviews).and_return("stubbed icp prompt")
      allow(adapter).to receive(:generate).and_return(result)
    end

    it "forwards reviews: to IcpPromptBuilder.build" do
      described_class.extract_icp(reviews: reviews)

      expect(IcpPromptBuilder).to have_received(:build).with(reviews: reviews)
    end

    it "calls the adapter with the built prompt and ICP_RESPONSE_SCHEMA" do
      described_class.extract_icp(reviews: reviews)

      expect(adapter).to have_received(:generate).with(prompt: "stubbed icp prompt", schema: LlmService::ICP_RESPONSE_SCHEMA)
    end

    it "returns the adapter's Result" do
      expect(described_class.extract_icp(reviews: reviews)).to be(result)
    end

    it "propagates LlmService::Error from the adapter unchanged" do
      error = LlmService::Error.new("HTTP 503")
      allow(adapter).to receive(:generate).and_raise(error)

      expect { described_class.extract_icp(reviews: reviews) }.to raise_error(be(error))
    end

    it "propagates LlmService::TruncatedResponseError from the adapter unchanged" do
      error = LlmService::TruncatedResponseError.new("truncated")
      allow(adapter).to receive(:generate).and_raise(error)

      expect { described_class.extract_icp(reviews: reviews) }.to raise_error(be(error))
    end
  end

  describe ".adapter" do
    before { allow(described_class).to receive(:adapter).and_call_original }

    it "returns an Llm::GeminiAdapter" do
      expect(described_class.adapter).to be_a(Llm::GeminiAdapter)
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
