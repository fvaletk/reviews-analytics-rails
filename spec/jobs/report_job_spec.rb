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
        "body" => "I really love this app, it works great every day",
        "reviewed_at" => "2024-01-01T00:00:00Z"
      },
      {
        "external_id" => "r2",
        "store" => "play_store",
        "author" => "Bob",
        "rating" => 4,
        "title" => nil,
        "body" => "Pretty good overall experience with this app",
        "reviewed_at" => "2024-01-02T00:00:00Z"
      },
      {
        "external_id" => "r3",
        "store" => "play_store",
        "author" => "Carol",
        "rating" => 3,
        "title" => nil,
        "body" => "It's okay but could definitely be better",
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

  let(:llm_usage) do
    { "promptTokenCount" => 1200, "candidatesTokenCount" => 340, "thoughtsTokenCount" => 56 }
  end

  let(:llm_analyze_result) { LlmService::Result.new(data: llm_result, usage: llm_usage) }

  before do
    allow(ScrapingService).to receive(:fetch).and_return(scraping_response)
    allow(LlmService).to receive(:analyze).and_return(llm_analyze_result)
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
        expect(LlmService).to have_received(:analyze).with(reviews: anything, distribution: anything)
      end

      it "records the model used for the call" do
        expect(report.reload.model).to eq(LlmService::MODEL)
      end

      it "records the input token count from the usage metadata" do
        expect(report.reload.input_tokens).to eq(1200)
      end

      it "records the output token count from the usage metadata" do
        expect(report.reload.output_tokens).to eq(340)
      end

      it "records the thinking token count from the usage metadata" do
        expect(report.reload.thinking_tokens).to eq(56)
      end

      it "records a non-negative llm_duration_ms" do
        expect(report.reload.llm_duration_ms).to be >= 0
      end

      it "computes cost_usd from LlmService.cost_usd using the recorded model and token counts" do
        expected_cost = LlmService.cost_usd(model: LlmService::MODEL, input_tokens: 1200, output_tokens: 340)

        expect(report.reload.cost_usd.to_f).to eq(expected_cost)
      end

      it "stores the raw usageMetadata in usage_metadata" do
        expect(report.reload.usage_metadata).to eq(llm_usage)
      end
    end

    context "schema validation receives the parsed hash, not the Result struct" do
      before do
        allow(ReportSchemaValidator).to receive(:validate!).and_call_original
        described_class.perform_now(report.id)
      end

      it "calls ReportSchemaValidator.validate! with result.data" do
        expect(ReportSchemaValidator).to have_received(:validate!).with(llm_result)
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

      it "leaves the usage columns nil rather than writing zeros" do
        report.reload
        expect([
          report.model,
          report.input_tokens,
          report.output_tokens,
          report.thinking_tokens,
          report.llm_duration_ms,
          report.cost_usd
        ]).to all(be_nil)
      end

      it "leaves selection_metadata at its NOT NULL default ({}) rather than partially writing it" do
        expect(report.reload.selection_metadata).to eq({})
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

      it "leaves the usage columns nil rather than writing zeros" do
        report.reload
        expect([
          report.model,
          report.input_tokens,
          report.output_tokens,
          report.thinking_tokens,
          report.llm_duration_ms,
          report.cost_usd
        ]).to all(be_nil)
      end

      it "leaves selection_metadata at its NOT NULL default ({})" do
        expect(report.reload.selection_metadata).to eq({})
      end
    end

    context "when an unexpected error occurs during a reanalyze-only run (skip_scraping: true)" do
      before do
        allow(LlmService).to receive(:analyze).and_raise(RuntimeError, "unexpected")
        described_class.perform_now(report.id, skip_scraping: true)
      end

      it "sets status to failed" do
        expect(report.reload.status).to eq("failed")
      end

      it "leaves the usage columns nil regardless of report_type" do
        report.reload
        expect([
          report.model,
          report.input_tokens,
          report.output_tokens,
          report.thinking_tokens,
          report.llm_duration_ms,
          report.cost_usd
        ]).to all(be_nil)
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
        expect(LlmService).to have_received(:analyze).with(reviews: anything, distribution: anything)
      end

      it "saves the LLM structured output" do
        expect(report.reload.structured_output).to eq(llm_result)
      end

      it "records the model used for the call" do
        expect(report.reload.model).to eq(LlmService::MODEL)
      end

      it "records the input, output, and thinking token counts from the usage metadata" do
        report.reload
        expect([ report.input_tokens, report.output_tokens, report.thinking_tokens ]).to eq([ 1200, 340, 56 ])
      end

      it "computes and stores cost_usd" do
        expected_cost = LlmService.cost_usd(model: LlmService::MODEL, input_tokens: 1200, output_tokens: 340)
        expect(report.reload.cost_usd.to_f).to eq(expected_cost)
      end

      it "stores the raw usageMetadata in usage_metadata" do
        expect(report.reload.usage_metadata).to eq(llm_usage)
      end
    end

    context "delegating review selection to ReviewSelector (BRA-84)" do
      let(:selected_app_store_reviews) { create_list(:review, 2, app: app, store: :app_store) }
      let(:selected_play_store_reviews) { create_list(:review, 3, app: app, store: :play_store) }

      let(:selection_metadata) do
        {
          filtered_out: { empty: 1, too_short: 2, duplicate: 0 },
          distribution: { "1" => 1, "2" => 1, "3" => 1, "4" => 1, "5" => 1, "unrated" => 0 },
          selected: {
            app_store: { negative: 0, mixed: 0, positive: 2, unrated: 0 },
            play_store: { negative: 1, mixed: 1, positive: 1, unrated: 0 }
          }
        }
      end

      let(:selection_result) do
        ReviewSelector::Result.new(
          app_store: selected_app_store_reviews,
          play_store: selected_play_store_reviews,
          metadata: selection_metadata
        )
      end

      before { allow(ReviewSelector).to receive(:select).and_return(selection_result) }

      context "on the scrape/generate path" do
        before { described_class.perform_now(report.id) }

        it "delegates to ReviewSelector.select" do
          expect(ReviewSelector).to have_received(:select)
        end

        it "sends exactly the reviews ReviewSelector selected (app_store + play_store) to LlmService" do
          expect(LlmService).to have_received(:analyze).with(
            reviews: selected_app_store_reviews + selected_play_store_reviews,
            distribution: anything
          )
        end

        it "forwards ReviewSelector's true distribution to LlmService.analyze" do
          expect(LlmService).to have_received(:analyze).with(
            reviews: anything,
            distribution: selection_metadata[:distribution]
          )
        end

        it "sets total_reviews_analyzed to the combined selected count" do
          expect(report.reload.total_reviews_analyzed).to eq(5)
        end

        it "sets app_store_reviews_count to the selected app_store count" do
          expect(report.reload.app_store_reviews_count).to eq(2)
        end

        it "sets play_store_reviews_count to the selected play_store count" do
          expect(report.reload.play_store_reviews_count).to eq(3)
        end

        it "persists selection_metadata exactly as returned by ReviewSelector" do
          expect(report.reload.selection_metadata).to eq(selection_metadata.deep_stringify_keys)
        end
      end

      context "on the reanalyze-only path (skip_scraping: true)" do
        before { described_class.perform_now(report.id, skip_scraping: true) }

        it "delegates to ReviewSelector.select using the app's stored reviews" do
          expect(ReviewSelector).to have_received(:select)
        end

        it "persists selection_metadata exactly as returned by ReviewSelector" do
          expect(report.reload.selection_metadata).to eq(selection_metadata.deep_stringify_keys)
        end

        it "sets total_reviews_analyzed to the combined selected count" do
          expect(report.reload.total_reviews_analyzed).to eq(5)
        end
      end
    end

    context "BRA-82 regression, on top of band stratification — a single-store app still receives up to MAX_REVIEWS_TOTAL" do
      let!(:app_store_reviews) do
        create_list(:review, 600, app: app, store: :app_store, reviewed_at: 1.day.ago)
      end

      before { described_class.perform_now(report.id, skip_scraping: true) }

      it "still produces a completed report" do
        expect(report.reload.status).to eq("complete")
      end

      it "sets total_reviews_analyzed to ReviewSelector::MAX_REVIEWS_TOTAL" do
        expect(report.reload.total_reviews_analyzed).to eq(ReviewSelector::MAX_REVIEWS_TOTAL)
      end

      it "sets app_store_reviews_count to ReviewSelector::MAX_REVIEWS_TOTAL" do
        expect(report.reload.app_store_reviews_count).to eq(ReviewSelector::MAX_REVIEWS_TOTAL)
      end

      it "sets play_store_reviews_count to 0" do
        expect(report.reload.play_store_reviews_count).to eq(0)
      end

      it "persists a non-empty selection_metadata reflecting the real ReviewSelector run" do
        metadata = report.reload.selection_metadata
        expect(metadata["distribution"].values.sum).to eq(600)
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

      it "leaves the usage columns nil rather than writing zeros" do
        report.reload
        expect([
          report.model,
          report.input_tokens,
          report.output_tokens,
          report.thinking_tokens,
          report.llm_duration_ms,
          report.cost_usd
        ]).to all(be_nil)
      end
    end
  end
end
