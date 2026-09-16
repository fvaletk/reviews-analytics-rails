# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Icps", type: :request do
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  let(:user)      { create(:user) }
  let(:workspace) { create(:workspace) }
  let(:the_app)   { create(:app, workspace: workspace) }

  ICP_COLUMNS = %i[
    icp icp_declined_reason icp_generated_at icp_model
    icp_input_tokens icp_output_tokens icp_cost_usd icp_usage_metadata
  ].freeze

  # This app's global ActiveJob adapter is :sidekiq (see config/application.rb).
  # Swap in the ActiveJob test adapter for the duration of these examples so
  # that `have_enqueued_job` works and no job is actually pushed to Redis.
  around do |example|
    original_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
    ActiveJob::Base.queue_adapter = original_adapter
  end

  # Ensure the user is a member of the workspace
  def make_member(u = user, role: :admin)
    create(:workspace_membership, user: u, workspace: workspace, role: role)
  end

  # ---------------------------------------------------------------------------
  # POST /workspaces/:workspace_id/apps/:app_id/icp
  # ---------------------------------------------------------------------------
  describe "POST /workspaces/:workspace_id/apps/:app_id/icp" do
    context "when signed in as an admin" do
      before do
        make_member(role: :admin)
        sign_in user
      end

      it "returns a turbo_stream response" do
        post workspace_app_icp_path(workspace, the_app), as: :turbo_stream
        expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
      end

      it "replaces the #app_icp target" do
        post workspace_app_icp_path(workspace, the_app), as: :turbo_stream
        doc = Nokogiri::HTML::Document.parse(response.body)
        turbo_stream_tag = doc.at_css("turbo-stream[target='app_icp']")
        expect(turbo_stream_tag).to be_present
      end

      it "renders a disabled button reading 'Generating…' inside the response" do
        post workspace_app_icp_path(workspace, the_app), as: :turbo_stream
        doc = Nokogiri::HTML::Document.parse(response.body)
        button = doc.css("button").find { |btn| btn.text.strip == "Generating…" }
        expect(button["disabled"]).to be_present
      end

      it "enqueues exactly one IcpExtractionJob with force: true" do
        expect {
          post workspace_app_icp_path(workspace, the_app)
        }.to have_enqueued_job(IcpExtractionJob).with(the_app.id, force: true).exactly(:once)
      end
    end

    context "when signed in as a super_admin" do
      before do
        make_member(role: :super_admin)
        sign_in user
      end

      it "returns a turbo_stream response" do
        post workspace_app_icp_path(workspace, the_app), as: :turbo_stream
        expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
      end

      it "enqueues an IcpExtractionJob with force: true" do
        expect {
          post workspace_app_icp_path(workspace, the_app)
        }.to have_enqueued_job(IcpExtractionJob).with(the_app.id, force: true)
      end
    end

    context "when signed in as a collaborator" do
      before do
        make_member(role: :collaborator)
        sign_in user
      end

      it "returns 403 Forbidden" do
        post workspace_app_icp_path(workspace, the_app)
        expect(response).to have_http_status(:forbidden)
      end

      it "does not enqueue an IcpExtractionJob" do
        expect {
          post workspace_app_icp_path(workspace, the_app)
        }.not_to have_enqueued_job(IcpExtractionJob)
      end
    end

    context "when the user has no membership in the workspace" do
      before { sign_in user }

      it "returns 404 Not Found" do
        post workspace_app_icp_path(workspace, the_app)
        expect(response).to have_http_status(:not_found)
      end

      it "does not enqueue an IcpExtractionJob" do
        expect {
          post workspace_app_icp_path(workspace, the_app)
        }.not_to have_enqueued_job(IcpExtractionJob)
      end
    end

    context "when not signed in" do
      it "redirects to sign in" do
        post workspace_app_icp_path(workspace, the_app)
        expect(response).to redirect_to(sign_in_path)
      end

      it "does not enqueue an IcpExtractionJob" do
        expect {
          post workspace_app_icp_path(workspace, the_app)
        }.not_to have_enqueued_job(IcpExtractionJob)
      end
    end

    context "the controller writes nothing to the app record" do
      let(:the_app) { create(:app, :with_icp, workspace: workspace) }

      before do
        make_member(role: :admin)
        sign_in user
      end

      it "leaves every icp_* column unchanged after the request" do
        before_attributes = the_app.reload.attributes.slice(*ICP_COLUMNS.map(&:to_s))

        post workspace_app_icp_path(workspace, the_app)

        after_attributes = the_app.reload.attributes.slice(*ICP_COLUMNS.map(&:to_s))
        expect(after_attributes).to eq(before_attributes)
      end
    end

    context "when a regenerate attempt fails at the job level" do
      let(:the_app) { create(:app, :with_icp, workspace: workspace) }

      before do
        make_member(role: :admin)
        sign_in user
        create_list(:review, 3, app: the_app, store: :app_store)
        allow(LlmService).to receive(:extract_icp).and_raise(LlmService::Error, "boom")
      end

      it "leaves the previous ICP result intact after the job runs" do
        before_attributes = the_app.reload.attributes.slice(*ICP_COLUMNS.map(&:to_s))

        perform_enqueued_jobs do
          post workspace_app_icp_path(workspace, the_app)
        end

        expect(LlmService).to have_received(:extract_icp)
        after_attributes = the_app.reload.attributes.slice(*ICP_COLUMNS.map(&:to_s))
        expect(after_attributes).to eq(before_attributes)
      end
    end
  end
end
