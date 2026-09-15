# frozen_string_literal: true

require "rails_helper"

RSpec.describe IcpSchemaValidator do
  let(:valid_signal) do
    { "quote" => "I manage three restaurants and this app saves me hours", "role_hint" => "restaurant manager" }
  end

  let(:valid_extraction) do
    {
      "primary_segment" => "restaurant managers",
      "confidence" => "high",
      "signals" => [ valid_signal ],
      "declined_reason" => nil
    }
  end

  let(:valid_decline) do
    {
      "primary_segment" => nil,
      "confidence" => nil,
      "signals" => [],
      "declined_reason" => "No first-person self-identification found in the reviews"
    }
  end

  describe ".validate!" do
    context "with a valid extraction" do
      it "does not raise" do
        expect { described_class.validate!(valid_extraction) }.not_to raise_error
      end
    end

    context "with a valid decline" do
      it "does not raise" do
        expect { described_class.validate!(valid_decline) }.not_to raise_error
      end
    end

    context "with symbol keys" do
      let(:symbol_hash) do
        {
          primary_segment: "restaurant managers",
          confidence: "high",
          signals: [ { quote: "I manage three restaurants", role_hint: "restaurant manager" } ],
          declined_reason: nil
        }
      end

      it "does not raise" do
        expect { described_class.validate!(symbol_hash) }.not_to raise_error
      end
    end

    context "when the argument is not a Hash" do
      it "raises for nil" do
        expect { described_class.validate!(nil) }
          .to raise_error(IcpSchemaValidator::InvalidSchema, /expected a Hash/)
      end

      it "raises for a String" do
        expect { described_class.validate!("not a hash") }
          .to raise_error(IcpSchemaValidator::InvalidSchema, /expected a Hash/)
      end

      it "raises for an Array" do
        expect { described_class.validate!([]) }
          .to raise_error(IcpSchemaValidator::InvalidSchema, /expected a Hash/)
      end
    end

    context "when a top-level key is missing" do
      %w[primary_segment confidence signals declined_reason].each do |key|
        it "raises when #{key} is missing" do
          hash = valid_extraction.reject { |k, _| k == key }
          expect { described_class.validate!(hash) }
            .to raise_error(IcpSchemaValidator::InvalidSchema, /missing key: #{key}/)
        end
      end
    end

    context "when signals is not an Array" do
      it "raises" do
        hash = valid_extraction.merge("signals" => "not an array")
        expect { described_class.validate!(hash) }
          .to raise_error(IcpSchemaValidator::InvalidSchema, /signals must be an Array/)
      end
    end

    context "when a signal is missing quote" do
      it "raises" do
        broken_signal = valid_signal.reject { |k, _| k == "quote" }
        hash = valid_extraction.merge("signals" => [ broken_signal ])
        expect { described_class.validate!(hash) }
          .to raise_error(IcpSchemaValidator::InvalidSchema, /signals\[0\] missing quote/)
      end
    end

    context "when a signal's quote is blank" do
      it "raises" do
        broken_signal = valid_signal.merge("quote" => "")
        hash = valid_extraction.merge("signals" => [ broken_signal ])
        expect { described_class.validate!(hash) }
          .to raise_error(IcpSchemaValidator::InvalidSchema, /signals\[0\] missing quote/)
      end
    end

    context "when a signal is missing role_hint" do
      it "raises" do
        broken_signal = valid_signal.reject { |k, _| k == "role_hint" }
        hash = valid_extraction.merge("signals" => [ broken_signal ])
        expect { described_class.validate!(hash) }
          .to raise_error(IcpSchemaValidator::InvalidSchema, /signals\[0\] missing role_hint/)
      end
    end

    context "when a signal's role_hint is blank" do
      it "raises" do
        broken_signal = valid_signal.merge("role_hint" => "")
        hash = valid_extraction.merge("signals" => [ broken_signal ])
        expect { described_class.validate!(hash) }
          .to raise_error(IcpSchemaValidator::InvalidSchema, /signals\[0\] missing role_hint/)
      end
    end

    context "when a signal is not a Hash" do
      it "raises" do
        hash = valid_extraction.merge("signals" => [ "not a hash" ])
        expect { described_class.validate!(hash) }
          .to raise_error(IcpSchemaValidator::InvalidSchema, /signals\[0\] must be a Hash/)
      end
    end

    context "when confidence is an invalid non-nil value" do
      it "raises" do
        hash = valid_extraction.merge("confidence" => "very high")
        expect { described_class.validate!(hash) }
          .to raise_error(IcpSchemaValidator::InvalidSchema, /invalid confidence/)
      end
    end

    context "with recognized confidence values" do
      %w[high medium low].each do |confidence|
        it "accepts #{confidence} without raising" do
          hash = valid_extraction.merge("confidence" => confidence)
          expect { described_class.validate!(hash) }.not_to raise_error
        end
      end
    end

    context "when confidence is nil" do
      it "does not raise on its own (decline case)" do
        hash = valid_decline
        expect { described_class.validate!(hash) }.not_to raise_error
      end
    end

    context "when primary_segment is blank but signals is non-empty" do
      it "raises for nil primary_segment" do
        hash = valid_extraction.merge("primary_segment" => nil)
        expect { described_class.validate!(hash) }
          .to raise_error(IcpSchemaValidator::InvalidSchema, /decline.*cannot carry signals/)
      end

      it "raises for an empty-string primary_segment" do
        hash = valid_extraction.merge("primary_segment" => "")
        expect { described_class.validate!(hash) }
          .to raise_error(IcpSchemaValidator::InvalidSchema, /decline.*cannot carry signals/)
      end
    end
  end
end
