# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReportJob, type: :job do
  let(:workspace) { create(:workspace) }
  let(:user) { create(:user) }
  let(:app) { create(:app, workspace: workspace, app_store_id: "12345", app_store_country: "us", play_store_id: nil) }
  let(:report) { create(:report, app: app, generated_by: user, status: :pending) }

  let(:scraped_reviews) do
    [
      {
        "external_id" => "r1",
        "store" => "app_store",
        "author" => "Alice",
        "rating" => 5,
        "title" => "Great app",
        "body" => "Love it",
        "reviewed_at" => "2024-01-01T00:00:00Z"
      }
    ]
  end

  let(:scraping_response) { { "reviews" => scraped_reviews } }
  let(:llm_result) { { "summary" => "Positive sentiment overall" } }

  before do
    allow(ScrapingService).to receive(:fetch).and_return(scraping_response)
    allow(LlmService).to receive(:analyze).and_return(llm_result)
    allow(ActionCable.server).to receive(:broadcast)
  end

  describe "#perform" do
    context "on the success path" do
      before { described_class.perform_now(report.id) }

      it "transitions through fetching → analyzing → complete" do
        expect(report.reload.status).to eq("complete")
      end

      it "saves the LLM structured output" do
        expect(report.reload.structured_output).to eq(llm_result)
      end

      it "records the number of reviews analyzed" do
        expect(report.reload.total_reviews_analyzed).to eq(1)
      end

      it "upserts reviews using insert_all" do
        expect(Review.where(app: app).count).to eq(1)
      end

      it "broadcasts on each status change" do
        expect(ActionCable.server).to have_received(:broadcast)
          .with("report_#{report.id}", anything).at_least(3).times
      end

      it "calls ScrapingService with the app store IDs" do
        expect(ScrapingService).to have_received(:fetch).with(
          app_store_id: "12345",
          app_store_country: "us",
          play_store_id: nil
        )
      end

      it "calls LlmService with the app reviews" do
        expect(LlmService).to have_received(:analyze).with(reviews: anything)
      end
    end

    context "when ScrapingService raises an error" do
      before do
        allow(ScrapingService).to receive(:fetch).and_raise(ScrapingService::Error, "timeout")
        described_class.perform_now(report.id)
      end

      it "sets status to failed" do
        expect(report.reload.status).to eq("failed")
      end

      it "saves the failure reason" do
        expect(report.reload.failure_reason).to eq("timeout")
      end

      it "broadcasts the failed status" do
        expect(ActionCable.server).to have_received(:broadcast)
          .with("report_#{report.id}", { status: "failed" })
      end
    end

    context "when an unexpected error occurs" do
      before do
        allow(LlmService).to receive(:analyze).and_raise(RuntimeError, "unexpected")
        described_class.perform_now(report.id)
      end

      it "sets status to failed" do
        expect(report.reload.status).to eq("failed")
      end

      it "saves the failure reason" do
        expect(report.reload.failure_reason).to eq("unexpected")
      end
    end
  end
end
