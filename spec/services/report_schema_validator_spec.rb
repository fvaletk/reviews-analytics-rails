# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReportSchemaValidator do
  let(:valid_pain_point) do
    {
      "title" => "Crashes on launch",
      "severity" => "high",
      "frequency" => 12,
      "description" => "App crashes immediately after opening on iOS 17"
    }
  end

  let(:valid_hash) do
    {
      "summary" => "Overall sentiment is mixed",
      "pain_points" => [valid_pain_point],
      "complaints" => [],
      "feature_requests" => [],
      "strengths" => [],
      "opportunities" => []
    }
  end

  describe ".validate!" do
    context "with a fully valid hash" do
      it "does not raise" do
        expect { described_class.validate!(valid_hash) }.not_to raise_error
      end
    end

    context "when all array keys are empty arrays" do
      it "does not raise" do
        hash = valid_hash.merge("pain_points" => [])
        expect { described_class.validate!(hash) }.not_to raise_error
      end
    end

    context "when the argument is not a Hash" do
      it "raises for nil" do
        expect { described_class.validate!(nil) }
          .to raise_error(ReportSchemaValidator::InvalidSchema, /expected a Hash/)
      end

      it "raises for a String" do
        expect { described_class.validate!("not a hash") }
          .to raise_error(ReportSchemaValidator::InvalidSchema, /expected a Hash/)
      end

      it "raises for an Array" do
        expect { described_class.validate!([]) }
          .to raise_error(ReportSchemaValidator::InvalidSchema, /expected a Hash/)
      end
    end

    context "when a top-level key is missing" do
      %w[summary pain_points complaints feature_requests strengths opportunities].each do |key|
        it "raises when #{key} is missing" do
          hash = valid_hash.reject { |k, _| k == key }
          expect { described_class.validate!(hash) }
            .to raise_error(ReportSchemaValidator::InvalidSchema, /missing key: #{key}/)
        end
      end
    end

    context "when a top-level array key is the wrong type" do
      %w[pain_points complaints feature_requests strengths opportunities].each do |key|
        it "raises when #{key} is a String instead of an Array" do
          hash = valid_hash.merge(key => "not an array")
          expect { described_class.validate!(hash) }
            .to raise_error(ReportSchemaValidator::InvalidSchema, /#{key} must be an Array/)
        end
      end
    end

    context "when a pain_points item is missing a required key" do
      %w[title severity frequency description].each do |key|
        it "raises when the pain point is missing #{key}" do
          broken_point = valid_pain_point.reject { |k, _| k == key }
          hash = valid_hash.merge("pain_points" => [broken_point])
          expect { described_class.validate!(hash) }
            .to raise_error(ReportSchemaValidator::InvalidSchema, /pain_points\[0\] missing key: #{key}/)
        end
      end
    end

    context "when a pain_points item is not a Hash" do
      it "raises" do
        hash = valid_hash.merge("pain_points" => ["not a hash"])
        expect { described_class.validate!(hash) }
          .to raise_error(ReportSchemaValidator::InvalidSchema, /pain_points\[0\] must be a Hash/)
      end
    end

    context "when a pain_points item has an unrecognized severity" do
      it "raises" do
        broken_point = valid_pain_point.merge("severity" => "urgent")
        hash = valid_hash.merge("pain_points" => [broken_point])
        expect { described_class.validate!(hash) }
          .to raise_error(ReportSchemaValidator::InvalidSchema, /pain_points\[0\] has invalid severity: "urgent"/)
      end
    end

    context "with recognized severities" do
      %w[critical high medium low].each do |severity|
        it "accepts #{severity} without raising" do
          point = valid_pain_point.merge("severity" => severity)
          hash = valid_hash.merge("pain_points" => [point])
          expect { described_class.validate!(hash) }.not_to raise_error
        end
      end
    end

    context "when the hash uses symbol keys" do
      let(:symbol_pain_point) do
        {
          title: "Crashes on launch",
          severity: "high",
          frequency: 12,
          description: "App crashes immediately after opening on iOS 17"
        }
      end

      let(:symbol_hash) do
        {
          summary: "Overall sentiment is mixed",
          pain_points: [symbol_pain_point],
          complaints: [],
          feature_requests: [],
          strengths: [],
          opportunities: []
        }
      end

      it "does not raise" do
        expect { described_class.validate!(symbol_hash) }.not_to raise_error
      end
    end

    context "when the hash uses string keys" do
      it "does not raise" do
        expect { described_class.validate!(valid_hash) }.not_to raise_error
      end
    end
  end
end
