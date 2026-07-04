# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Reports", type: :request do
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  let(:user)      { create(:user) }
  let(:workspace) { create(:workspace) }
  let(:the_app)   { create(:app, workspace: workspace) }

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
  # POST /workspaces/:workspace_id/apps/:app_id/reports
  # ---------------------------------------------------------------------------
  describe "POST /workspaces/:workspace_id/apps/:app_id/reports" do
    context "when signed in as an admin" do
      before do
        make_member(role: :admin)
        sign_in user
      end

      it "creates a Report record" do
        expect {
          post workspace_app_reports_path(workspace, the_app)
        }.to change(Report, :count).by(1)
      end

      it "sets the report status to pending" do
        post workspace_app_reports_path(workspace, the_app)
        expect(Report.last.status).to eq("pending")
      end

      it "sets generated_by to the current user" do
        post workspace_app_reports_path(workspace, the_app)
        expect(Report.last.generated_by).to eq(user)
      end

      it "enqueues a ReportJob with the new report's id" do
        post workspace_app_reports_path(workspace, the_app)
        report = Report.last
        enqueued = ActiveJob::Base.queue_adapter.enqueued_jobs.find { |j| j["job_class"] == "ReportJob" }
        expect(enqueued["arguments"]).to eq([report.id])
      end

      it "returns a turbo_stream response" do
        post workspace_app_reports_path(workspace, the_app), as: :turbo_stream
        expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
      end

      it "renders the Generating indicator" do
        post workspace_app_reports_path(workspace, the_app)
        expect(response.body).to include("Generating")
      end
    end

    context "when signed in as a super_admin" do
      before do
        make_member(role: :super_admin)
        sign_in user
      end

      it "creates a Report record" do
        expect {
          post workspace_app_reports_path(workspace, the_app)
        }.to change(Report, :count).by(1)
      end

      it "enqueues a ReportJob" do
        expect {
          post workspace_app_reports_path(workspace, the_app)
        }.to have_enqueued_job(ReportJob)
      end
    end

    context "when signed in as a collaborator" do
      before do
        make_member(role: :collaborator)
        sign_in user
      end

      it "returns 403 Forbidden" do
        post workspace_app_reports_path(workspace, the_app)
        expect(response).to have_http_status(:forbidden)
      end

      it "does not create a Report record" do
        expect {
          post workspace_app_reports_path(workspace, the_app)
        }.not_to change(Report, :count)
      end

      it "does not enqueue a ReportJob" do
        expect {
          post workspace_app_reports_path(workspace, the_app)
        }.not_to have_enqueued_job(ReportJob)
      end
    end

    context "when the user has no membership in the workspace" do
      before { sign_in user }

      it "returns 404 Not Found" do
        post workspace_app_reports_path(workspace, the_app)
        expect(response).to have_http_status(:not_found)
      end

      it "does not create a Report record" do
        expect {
          post workspace_app_reports_path(workspace, the_app)
        }.not_to change(Report, :count)
      end
    end

    context "when not signed in" do
      it "redirects to sign in" do
        post workspace_app_reports_path(workspace, the_app)
        expect(response).to redirect_to(sign_in_path)
      end

      it "does not create a Report record" do
        expect {
          post workspace_app_reports_path(workspace, the_app)
        }.not_to change(Report, :count)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Generate Report button visibility on the app show page
  # ---------------------------------------------------------------------------
  describe "GET /workspaces/:workspace_id/apps/:id — Generate Report button visibility" do
    context "when signed in as an admin" do
      before do
        make_member(role: :admin)
        sign_in user
      end

      it "shows the Generate Report button" do
        get workspace_app_path(workspace, the_app)
        expect(response.body).to include("Generate Report")
      end
    end

    context "when signed in as a super_admin" do
      before do
        make_member(role: :super_admin)
        sign_in user
      end

      it "shows the Generate Report button" do
        get workspace_app_path(workspace, the_app)
        expect(response.body).to include("Generate Report")
      end
    end

    context "when signed in as a collaborator" do
      before do
        make_member(role: :collaborator)
        sign_in user
      end

      it "hides the Generate Report button" do
        get workspace_app_path(workspace, the_app)
        expect(response.body).not_to include("Generate Report")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Re-analyze existing reviews button visibility on the app show page
  # ---------------------------------------------------------------------------
  describe "GET /workspaces/:workspace_id/apps/:id — Re-analyze existing reviews button visibility" do
    context "when signed in as an admin and a completed report exists" do
      before do
        make_member(role: :admin)
        sign_in user
        create(:report, app: the_app, status: :complete)
      end

      it "shows the Re-analyze existing reviews button" do
        get workspace_app_path(workspace, the_app)
        expect(response.body).to include("Re-analyze existing reviews")
      end
    end

    context "when signed in as a super_admin and a completed report exists" do
      before do
        make_member(role: :super_admin)
        sign_in user
        create(:report, app: the_app, status: :complete)
      end

      it "shows the Re-analyze existing reviews button" do
        get workspace_app_path(workspace, the_app)
        expect(response.body).to include("Re-analyze existing reviews")
      end
    end

    context "when signed in as an admin but no completed report exists" do
      before do
        make_member(role: :admin)
        sign_in user
        create(:report, app: the_app, status: :pending)
      end

      it "hides the Re-analyze existing reviews button" do
        get workspace_app_path(workspace, the_app)
        expect(response.body).not_to include("Re-analyze existing reviews")
      end
    end

    context "when signed in as a collaborator and a completed report exists" do
      before do
        make_member(role: :collaborator)
        sign_in user
        create(:report, app: the_app, status: :complete)
      end

      it "hides the Re-analyze existing reviews button" do
        get workspace_app_path(workspace, the_app)
        expect(response.body).not_to include("Re-analyze existing reviews")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /workspaces/:workspace_id/apps/:app_id/reports/:id/reanalyze
  # ---------------------------------------------------------------------------
  describe "POST /workspaces/:workspace_id/apps/:app_id/reports/:id/reanalyze" do
    let(:existing_report) { create(:report, app: the_app, status: :complete) }

    context "when signed in as an admin" do
      before do
        make_member(role: :admin)
        sign_in user
      end

      it "creates a new Report record" do
        existing_report
        expect {
          post reanalyze_workspace_app_report_path(workspace, the_app, existing_report)
        }.to change(Report, :count).by(1)
      end

      it "does not modify the existing report's status" do
        existing_report
        post reanalyze_workspace_app_report_path(workspace, the_app, existing_report)
        expect(existing_report.reload.status).to eq("complete")
      end

      it "sets the new report's status to pending" do
        existing_report
        post reanalyze_workspace_app_report_path(workspace, the_app, existing_report)
        expect(Report.order(:created_at).last.status).to eq("pending")
      end

      it "sets generated_by to the current user on the new report" do
        existing_report
        post reanalyze_workspace_app_report_path(workspace, the_app, existing_report)
        expect(Report.order(:created_at).last.generated_by).to eq(user)
      end

      it "enqueues a ReportJob with skip_scraping: true for the new report" do
        existing_report
        expect {
          post reanalyze_workspace_app_report_path(workspace, the_app, existing_report)
        }.to have_enqueued_job(ReportJob).with { |report_id, **kwargs|
          expect(report_id).to eq(Report.order(:created_at).last.id)
          expect(kwargs).to eq(skip_scraping: true)
        }
      end

      it "returns a turbo_stream response" do
        existing_report
        post reanalyze_workspace_app_report_path(workspace, the_app, existing_report), as: :turbo_stream
        expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
      end
    end

    context "when signed in as a super_admin" do
      before do
        make_member(role: :super_admin)
        sign_in user
      end

      it "creates a new Report record" do
        existing_report
        expect {
          post reanalyze_workspace_app_report_path(workspace, the_app, existing_report)
        }.to change(Report, :count).by(1)
      end
    end

    context "when signed in as a collaborator" do
      before do
        make_member(role: :collaborator)
        sign_in user
      end

      it "returns 403 Forbidden" do
        existing_report
        post reanalyze_workspace_app_report_path(workspace, the_app, existing_report)
        expect(response).to have_http_status(:forbidden)
      end

      it "does not create a new Report record" do
        existing_report
        expect {
          post reanalyze_workspace_app_report_path(workspace, the_app, existing_report)
        }.not_to change(Report, :count)
      end
    end

    context "with a report id that does not belong to this app" do
      let(:other_app) { create(:app, workspace: workspace) }
      let(:foreign_report) { create(:report, app: other_app, status: :complete) }

      before do
        make_member(role: :admin)
        sign_in user
      end

      it "returns 404 Not Found" do
        foreign_report
        post reanalyze_workspace_app_report_path(workspace, the_app, foreign_report)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when not signed in" do
      it "redirects to sign in" do
        existing_report
        post reanalyze_workspace_app_report_path(workspace, the_app, existing_report)
        expect(response).to redirect_to(sign_in_path)
      end

      it "does not create a new Report record" do
        existing_report
        expect {
          post reanalyze_workspace_app_report_path(workspace, the_app, existing_report)
        }.not_to change(Report, :count)
      end
    end
  end
end
