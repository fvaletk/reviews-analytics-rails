# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReportJob, type: :job do
  describe "::MAX_REVIEWS_PER_ANALYSIS" do
    it "is capped at 500" do
      expect(described_class::MAX_REVIEWS_PER_ANALYSIS).to eq(500)
    end
  end

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
      },
      {
        "external_id" => "r2",
        "store" => "play_store",
        "author" => "Bob",
        "rating" => 4,
        "title" => nil,
        "body" => "Pretty good",
        "reviewed_at" => "2024-01-02T00:00:00Z"
      },
      {
        "external_id" => "r3",
        "store" => "play_store",
        "author" => "Carol",
        "rating" => 3,
        "title" => nil,
        "body" => "It's okay",
        "reviewed_at" => "2024-01-03T00:00:00Z"
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
        expect(report.reload.total_reviews_analyzed).to eq(3)
      end

      it "upserts reviews using insert_all" do
        expect(Review.where(app: app).count).to eq(3)
      end

      it "sets app_store_reviews_count based on the reviews actually analyzed" do
        expect(report.reload.app_store_reviews_count).to eq(1)
      end

      it "sets play_store_reviews_count based on the reviews actually analyzed" do
        expect(report.reload.play_store_reviews_count).to eq(2)
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

      it "broadcasts the unread_count to the collaborator's own notification stream" do
        expect(ActionCable.server).to have_received(:broadcast)
          .with("notifications_user_#{collaborator.id}", { unread_count: 1 })
      end

      it "broadcasts the unread_count to the admin's own notification stream" do
        expect(ActionCable.server).to have_received(:broadcast)
          .with("notifications_user_#{admin.id}", { unread_count: 1 })
      end

      it "broadcasts the unread_count to the super_admin's own notification stream" do
        expect(ActionCable.server).to have_received(:broadcast)
          .with("notifications_user_#{super_admin.id}", { unread_count: 1 })
      end
    end

    context "broadcasting the live notification via Turbo Streams (BRA-76)" do
      let(:collaborator) { create(:user) }
      let(:admin) { create(:user) }

      let!(:memberships) do
        [
          create(:workspace_membership, user: collaborator, workspace: workspace, role: :collaborator),
          create(:workspace_membership, user: admin, workspace: workspace, role: :admin)
        ]
      end

      before do
        allow(Turbo::StreamsChannel).to receive(:broadcast_remove_to)
        allow(Turbo::StreamsChannel).to receive(:broadcast_prepend_to)
        described_class.perform_now(report.id)
      end

      it "removes the empty-state element on the collaborator's notification stream" do
        expect(Turbo::StreamsChannel).to have_received(:broadcast_remove_to)
          .with(collaborator, :notifications, target: "notification_empty")
      end

      it "removes the empty-state element on the admin's notification stream" do
        expect(Turbo::StreamsChannel).to have_received(:broadcast_remove_to)
          .with(admin, :notifications, target: "notification_empty")
      end

      it "prepends the notification partial to the notification_list target on the collaborator's stream" do
        expect(Turbo::StreamsChannel).to have_received(:broadcast_prepend_to).with(
          collaborator,
          :notifications,
          target: "notification_list",
          partial: "notifications/notification",
          locals: { notification: anything }
        )
      end

      it "prepends the notification partial to the notification_list target on the admin's stream" do
        expect(Turbo::StreamsChannel).to have_received(:broadcast_prepend_to).with(
          admin,
          :notifications,
          target: "notification_list",
          partial: "notifications/notification",
          locals: { notification: anything }
        )
      end

      it "broadcasts a notification with a real persisted id, not an in-memory hash" do
        expect(Turbo::StreamsChannel).to have_received(:broadcast_prepend_to).with(
          collaborator,
          :notifications,
          hash_including(
            locals: { notification: satisfy { |n| n.is_a?(Notification) && n.persisted? && n.id.present? } }
          )
        )
      end

      it "broadcasts the collaborator's own persisted notification record" do
        expect(Turbo::StreamsChannel).to have_received(:broadcast_prepend_to).with(
          collaborator,
          :notifications,
          hash_including(
            locals: { notification: satisfy { |n| n.user_id == collaborator.id } }
          )
        )
      end

      it "broadcasts a notification with the correct message" do
        expect(Turbo::StreamsChannel).to have_received(:broadcast_prepend_to).with(
          collaborator,
          :notifications,
          hash_including(
            locals: { notification: satisfy { |n| n.message == "Report for #{app.name} is ready." } }
          )
        )
      end

      it "broadcasts a notification with the correct report_id" do
        expect(Turbo::StreamsChannel).to have_received(:broadcast_prepend_to).with(
          collaborator,
          :notifications,
          hash_including(
            locals: { notification: satisfy { |n| n.report_id == report.id } }
          )
        )
      end

      it "still broadcasts the unread_count on the same ActionCable stream (badge behavior unchanged)" do
        expect(ActionCable.server).to have_received(:broadcast)
          .with("notifications_user_#{collaborator.id}", { unread_count: 1 })
      end
    end

    context "when a workspace member already has prior read and unread notifications" do
      let(:collaborator) { create(:user) }
      let(:other_report) { create(:report, app: app, generated_by: user) }

      let!(:membership) do
        create(:workspace_membership, user: collaborator, workspace: workspace, role: :collaborator)
      end

      let!(:read_notification) do
        create(:notification, user: collaborator, workspace: workspace, report: other_report, read_at: 1.day.ago)
      end

      let!(:unread_notification) do
        create(:notification, user: collaborator, workspace: workspace, report: other_report)
      end

      before { described_class.perform_now(report.id) }

      it "broadcasts an unread_count that includes prior unread notifications plus the new one" do
        expect(ActionCable.server).to have_received(:broadcast)
          .with("notifications_user_#{collaborator.id}", { unread_count: 2 })
      end

      it "does not count the already-read notification" do
        expect(Notification.unread_count_for(collaborator)).to eq(2)
      end
    end

    context "when a workspace member marks all their notifications as read" do
      let(:collaborator) { create(:user) }

      let!(:membership) do
        create(:workspace_membership, user: collaborator, workspace: workspace, role: :collaborator)
      end

      before { described_class.perform_now(report.id) }

      it "the unread_count drops to 0 once all notifications are marked read" do
        Notification.where(user: collaborator).update_all(read_at: Time.current)

        expect(Notification.unread_count_for(collaborator)).to eq(0)
      end
    end

    context "when one workspace member has unread notifications from an unrelated workspace" do
      let(:collaborator) { create(:user) }
      let(:admin) { create(:user) }
      let(:other_workspace) { create(:workspace) }
      let(:other_app) { create(:app, workspace: other_workspace) }
      let(:other_report) { create(:report, app: other_app, generated_by: user) }

      let!(:memberships) do
        [
          create(:workspace_membership, user: collaborator, workspace: workspace, role: :collaborator),
          create(:workspace_membership, user: admin, workspace: workspace, role: :admin)
        ]
      end

      let!(:unrelated_notification) do
        create(:notification, user: collaborator, workspace: other_workspace, report: other_report)
      end

      before { described_class.perform_now(report.id) }

      it "includes the collaborator's unrelated unread notification in their own count" do
        expect(ActionCable.server).to have_received(:broadcast)
          .with("notifications_user_#{collaborator.id}", { unread_count: 2 })
      end

      it "does not leak the collaborator's extra notification into the admin's count" do
        expect(ActionCable.server).to have_received(:broadcast)
          .with("notifications_user_#{admin.id}", { unread_count: 1 })
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

      it "broadcasts the unread_count to each affected member's own notification stream" do
        expect(ActionCable.server).to have_received(:broadcast)
          .with("notifications_user_#{collaborator.id}", { unread_count: 1 })
        expect(ActionCable.server).to have_received(:broadcast)
          .with("notifications_user_#{admin.id}", { unread_count: 1 })
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

    context "when skip_scraping: true" do
      let!(:existing_reviews) do
        create_list(:review, 3, app: app, store: :app_store, reviewed_at: 1.day.ago) +
          create_list(:review, 2, app: app, store: :play_store, reviewed_at: 1.day.ago)
      end

      before { described_class.perform_now(report.id, skip_scraping: true) }

      it "does not call ScrapingService" do
        expect(ScrapingService).not_to have_received(:fetch)
      end

      it "does not create new reviews" do
        expect(Review.where(app: app).count).to eq(existing_reviews.size)
      end

      it "transitions the report to complete" do
        expect(report.reload.status).to eq("complete")
      end

      it "does not transition through fetching" do
        expect(ActionCable.server).not_to have_received(:broadcast)
          .with("report_#{report.id}", hash_including(status: "fetching"))
      end

      it "still transitions through analyzing" do
        expect(ActionCable.server).to have_received(:broadcast)
          .with("report_#{report.id}", hash_including(status: "analyzing"))
      end

      it "sets total_reviews_analyzed to the count of existing reviews used" do
        expect(report.reload.total_reviews_analyzed).to eq(
          app.reviews.order(reviewed_at: :desc).limit(500).size
        )
      end

      it "sets app_store_reviews_count based on the existing reviews used" do
        expect(report.reload.app_store_reviews_count).to eq(3)
      end

      it "sets play_store_reviews_count based on the existing reviews used" do
        expect(report.reload.play_store_reviews_count).to eq(2)
      end

      it "calls LlmService with the existing reviews" do
        expect(LlmService).to have_received(:analyze).with(reviews: anything)
      end

      it "saves the LLM structured output" do
        expect(report.reload.structured_output).to eq(llm_result)
      end
    end

    context "when review count is below the cap" do
      before do
        allow(Rails.logger).to receive(:info).and_call_original
        described_class.perform_now(report.id)
      end

      it "does not emit the review cap log line" do
        expect(Rails.logger).not_to have_received(:info).with(/review cap applied/)
      end
    end

    context "when the review count exactly equals the cap" do
      before { stub_const("ReportJob::MAX_REVIEWS_PER_ANALYSIS", 3) }

      before do
        allow(Rails.logger).to receive(:info).and_call_original
        described_class.perform_now(report.id)
      end

      it "emits the review cap log line" do
        expect(Rails.logger).to have_received(:info).with(/review cap applied/)
      end
    end

    context "when the review cap is exceeded on re-analyze (skip_scraping: true)" do
      before { stub_const("ReportJob::MAX_REVIEWS_PER_ANALYSIS", 5) }

      let!(:older_reviews) do
        create_list(:review, 4, app: app, store: :app_store, reviewed_at: 10.days.ago)
      end

      let!(:newer_reviews) do
        create_list(:review, 5, app: app, store: :app_store, reviewed_at: 1.day.ago)
      end

      before do
        allow(Rails.logger).to receive(:info).and_call_original
        described_class.perform_now(report.id, skip_scraping: true)
      end

      it "sends only MAX_REVIEWS_PER_ANALYSIS reviews to LlmService" do
        expect(LlmService).to have_received(:analyze).with(reviews: satisfy { |r| r.size == 5 })
      end

      it "sends only the most recently reviewed reviews to LlmService" do
        expect(LlmService).to have_received(:analyze).with(
          reviews: satisfy { |r| r.map(&:id).sort == newer_reviews.map(&:id).sort }
        )
      end

      it "excludes the older reviews beyond the cap" do
        expect(LlmService).to have_received(:analyze).with(
          reviews: satisfy { |r| (r.map(&:id) & older_reviews.map(&:id)).empty? }
        )
      end

      it "emits the review cap log line" do
        expect(Rails.logger).to have_received(:info).with(/review cap applied/)
      end

      it "sets total_reviews_analyzed to the capped count (reviews_for_analysis.size)" do
        expect(report.reload.total_reviews_analyzed).to eq(5)
      end
    end

    context "when the review cap is exceeded on generate (skip_scraping: false)" do
      before { stub_const("ReportJob::MAX_REVIEWS_PER_ANALYSIS", 5) }

      let!(:pre_existing_reviews) do
        create_list(:review, 3, app: app, store: :app_store, reviewed_at: 30.days.ago)
      end

      let(:scraped_reviews) do
        (1..5).map do |i|
          {
            "external_id" => "new-#{i}",
            "store" => "app_store",
            "author" => "Author #{i}",
            "rating" => 5,
            "title" => "Title #{i}",
            "body" => "Body #{i}",
            "reviewed_at" => (1.day.ago + i.hours).iso8601
          }
        end
      end

      before do
        allow(Rails.logger).to receive(:info).and_call_original
        described_class.perform_now(report.id)
      end

      it "sends only MAX_REVIEWS_PER_ANALYSIS reviews to LlmService" do
        expect(LlmService).to have_received(:analyze).with(reviews: satisfy { |r| r.size == 5 })
      end

      it "sends only the most recently reviewed reviews to LlmService, excluding the older pre-existing ones" do
        expect(LlmService).to have_received(:analyze).with(
          reviews: satisfy { |r| r.map(&:external_id).sort == scraped_reviews.map { |sr| sr["external_id"] }.sort }
        )
      end

      it "emits the review cap log line" do
        expect(Rails.logger).to have_received(:info).with(/review cap applied/)
      end

      it "sets total_reviews_analyzed to the count of newly scraped reviews, not the capped count" do
        expect(report.reload.total_reviews_analyzed).to eq(scraped_reviews.size)
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
