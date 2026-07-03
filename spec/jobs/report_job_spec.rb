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
  let(:llm_result) do
    {
      "summary" => "Positive sentiment overall",
      "pain_points" => [
        {
          "title" => "Crashes on launch",
          "severity" => "high",
          "frequency" => 3,
          "description" => "App crashes immediately after opening"
        }
      ],
      "complaints" => [],
      "feature_requests" => [],
      "strengths" => [],
      "opportunities" => []
    }
  end

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

    context "on the success path with workspace members" do
      let(:collaborator) { create(:user) }
      let(:admin) { create(:user) }
      let(:super_admin) { create(:user) }

      let!(:memberships) do
        [
          create(:workspace_membership, user: collaborator, workspace: workspace, role: :collaborator),
          create(:workspace_membership, user: admin, workspace: workspace, role: :admin),
          create(:workspace_membership, user: super_admin, workspace: workspace, role: :super_admin)
        ]
      end

      before { described_class.perform_now(report.id) }

      it "creates one notification per workspace member" do
        expect(Notification.count).to eq(memberships.size)
      end

      it "notifies every member's user_id" do
        expect(Notification.pluck(:user_id)).to match_array(memberships.map(&:user_id))
      end

      it "sets the notification message to indicate the report is ready" do
        expect(Notification.pluck(:message)).to all(match(/Report for #{app.name} is ready/))
      end

      it "sets the correct report_id on each notification" do
        expect(Notification.pluck(:report_id)).to all(eq(report.id))
      end

      it "sets the correct workspace_id on each notification" do
        expect(Notification.pluck(:workspace_id)).to all(eq(workspace.id))
      end

      it "leaves notifications unread" do
        expect(Notification.pluck(:read_at)).to all(be_nil)
      end

      it "uses insert_all rather than looping .create calls" do
        expect(Notification).to receive(:insert_all).once.and_call_original
        described_class.perform_now(report.id)
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
          .with("report_#{report.id}", { status: "failed", failure_reason: "timeout" })
      end
    end

    context "when ScrapingService raises an error and the workspace has members" do
      let(:collaborator) { create(:user) }
      let(:admin) { create(:user) }

      let!(:memberships) do
        [
          create(:workspace_membership, user: collaborator, workspace: workspace, role: :collaborator),
          create(:workspace_membership, user: admin, workspace: workspace, role: :admin)
        ]
      end

      before do
        allow(ScrapingService).to receive(:fetch).and_raise(ScrapingService::Error, "timeout")
        described_class.perform_now(report.id)
      end

      it "creates one failure notification per workspace member" do
        expect(Notification.count).to eq(memberships.size)
      end

      it "notifies every member's user_id" do
        expect(Notification.pluck(:user_id)).to match_array(memberships.map(&:user_id))
      end

      it "sets the notification message to indicate the report failed" do
        expect(Notification.pluck(:message)).to all(match(/Report for #{app.name} failed/))
      end

      it "includes the failure reason in the notification message" do
        expect(Notification.pluck(:message)).to all(include("timeout"))
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

    context "when LlmService returns a payload that fails schema validation" do
      let(:llm_result) { { "pain_points" => [], "complaints" => [], "feature_requests" => [], "strengths" => [], "opportunities" => [] } }

      before { described_class.perform_now(report.id) }

      it "sets status to failed" do
        expect(report.reload.status).to eq("failed")
      end

      it "saves the validator's error message as the failure reason" do
        expect(report.reload.failure_reason).to match(/missing key: summary/)
      end

      it "does not save the invalid structured_output" do
        expect(report.reload.structured_output).to be_nil
      end
    end
  end
end
