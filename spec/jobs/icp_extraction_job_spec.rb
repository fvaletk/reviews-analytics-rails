# frozen_string_literal: true

require "rails_helper"

RSpec.describe IcpExtractionJob, type: :job do
  let(:workspace) { create(:workspace) }
  let(:app) { create(:app, workspace: workspace, app_store_id: "12345", play_store_id: nil) }

  let!(:reviews) { create_list(:review, 3, app: app, store: :app_store) }

  let(:extraction_data) do
    {
      "primary_segment" => "restaurant managers",
      "confidence" => "high",
      "signals" => [
        { "quote" => "I manage three restaurants and this app saves me hours", "role_hint" => "restaurant manager" }
      ],
      "declined_reason" => nil
    }
  end

  let(:decline_data) do
    {
      "primary_segment" => nil,
      "confidence" => nil,
      "signals" => [],
      "declined_reason" => "No first-person self-identification found in the reviews"
    }
  end

  let(:icp_usage) { { "promptTokenCount" => 900, "candidatesTokenCount" => 40, "totalTokenCount" => 940 } }

  let(:selection_result) do
    ReviewSelector::Result.new(app_store: reviews, play_store: [], metadata: {})
  end

  before do
    allow(ReviewSelector).to receive(:select).and_return(selection_result)
    allow(LlmService).to receive(:extract_icp)
  end

  describe "#perform" do
    context "when the app has already attempted extraction" do
      let(:app) { create(:app, :icp_declined, workspace: workspace) }

      it "returns early without calling LlmService" do
        described_class.perform_now(app.id)

        expect(LlmService).not_to have_received(:extract_icp)
      end

      it "does not call ReviewSelector" do
        described_class.perform_now(app.id)

        expect(ReviewSelector).not_to have_received(:select)
      end
    end

    context "delegating review selection to ReviewSelector" do
      before do
        allow(LlmService).to receive(:extract_icp).and_return(LlmService::Result.new(data: extraction_data, usage: icp_usage))
        described_class.perform_now(app.id)
      end

      it "calls ReviewSelector.select with the app's reviews" do
        expect(ReviewSelector).to have_received(:select).with(app.reviews)
      end
    end

    context "when review selection is empty" do
      let(:selection_result) do
        ReviewSelector::Result.new(app_store: [], play_store: [], metadata: {})
      end

      before { described_class.perform_now(app.id) }

      it "does not call LlmService" do
        expect(LlmService).not_to have_received(:extract_icp)
      end

      it "does not persist anything" do
        app.reload
        expect(app.icp).to be_nil
        expect(app.icp_declined_reason).to be_nil
        expect(app.icp_generated_at).to be_nil
      end

      it "leaves icp_extraction_attempted? false" do
        expect(app.reload.icp_extraction_attempted?).to be false
      end
    end

    context "on a successful extraction" do
      before do
        allow(LlmService).to receive(:extract_icp).and_return(LlmService::Result.new(data: extraction_data, usage: icp_usage))
        described_class.perform_now(app.id)
        app.reload
      end

      it "persists the primary_segment" do
        expect(app.icp["primary_segment"]).to eq("restaurant managers")
      end

      it "persists the confidence" do
        expect(app.icp["confidence"]).to eq("high")
      end

      it "persists the signals" do
        expect(app.icp["signals"]).to eq(extraction_data["signals"])
      end

      it "leaves icp_declined_reason nil" do
        expect(app.icp_declined_reason).to be_nil
      end

      it "records the model used" do
        expect(app.icp_model).to eq(LlmService::MODEL)
      end

      it "records the input token count" do
        expect(app.icp_input_tokens).to eq(900)
      end

      it "records the output token count" do
        expect(app.icp_output_tokens).to eq(40)
      end

      it "computes and stores icp_cost_usd" do
        expected_cost = LlmService.cost_usd(model: LlmService::MODEL, input_tokens: 900, output_tokens: 40)
        expect(app.icp_cost_usd.to_f).to eq(expected_cost)
      end

      it "stores the raw usage metadata" do
        expect(app.icp_usage_metadata).to eq(icp_usage)
      end

      it "sets icp_generated_at" do
        expect(app.icp_generated_at).to be_present
      end
    end

    context "on a declined extraction" do
      before do
        allow(LlmService).to receive(:extract_icp).and_return(LlmService::Result.new(data: decline_data, usage: icp_usage))
        described_class.perform_now(app.id)
        app.reload
      end

      it "leaves icp nil" do
        expect(app.icp).to be_nil
      end

      it "persists the declined_reason" do
        expect(app.icp_declined_reason).to eq("No first-person self-identification found in the reviews")
      end

      it "still records usage columns" do
        expect([ app.icp_model, app.icp_input_tokens, app.icp_output_tokens, app.icp_cost_usd ]).to all(be_present)
      end

      it "still sets icp_generated_at" do
        expect(app.icp_generated_at).to be_present
      end
    end

    context "when LlmService raises LlmService::Error" do
      before do
        allow(LlmService).to receive(:extract_icp).and_raise(LlmService::Error, "boom")
      end

      it "does not raise" do
        expect { described_class.perform_now(app.id) }.not_to raise_error
      end

      it "leaves every icp_* column nil" do
        described_class.perform_now(app.id)
        app.reload

        expect([
          app.icp,
          app.icp_declined_reason,
          app.icp_model,
          app.icp_input_tokens,
          app.icp_output_tokens,
          app.icp_cost_usd,
          app.icp_generated_at
        ]).to all(be_nil)
      end

      it "leaves icp_usage_metadata at its default empty hash" do
        described_class.perform_now(app.id)
        expect(app.reload.icp_usage_metadata).to eq({})
      end
    end

    context "when LlmService raises LlmService::TruncatedResponseError" do
      before do
        allow(LlmService).to receive(:extract_icp).and_raise(LlmService::TruncatedResponseError, "truncated")
      end

      it "does not raise" do
        expect { described_class.perform_now(app.id) }.not_to raise_error
      end

      it "leaves every icp_* column nil" do
        described_class.perform_now(app.id)
        app.reload

        expect([
          app.icp,
          app.icp_declined_reason,
          app.icp_model,
          app.icp_generated_at
        ]).to all(be_nil)
      end
    end

    context "when the response fails IcpSchemaValidator" do
      let(:invalid_data) { { "primary_segment" => "x" } }

      before do
        allow(LlmService).to receive(:extract_icp).and_return(LlmService::Result.new(data: invalid_data, usage: icp_usage))
      end

      it "does not raise" do
        expect { described_class.perform_now(app.id) }.not_to raise_error
      end

      it "leaves every icp_* column nil" do
        described_class.perform_now(app.id)
        app.reload

        expect([
          app.icp,
          app.icp_declined_reason,
          app.icp_model,
          app.icp_generated_at
        ]).to all(be_nil)
      end

      it "does not persist icp_usage_metadata from the failed attempt" do
        described_class.perform_now(app.id)
        expect(app.reload.icp_usage_metadata).to eq({})
      end
    end
  end
end
