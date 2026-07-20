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

      # BRA-77
      it "sets report_type to generate" do
        post workspace_app_reports_path(workspace, the_app)
        expect(Report.last.report_type).to eq("generate")
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

      # BRA-75: the turbo_stream response must contain a real #report_status
      # element (the original bug was a missing turbo_stream target), and the
      # buttons rendered inside it must already be disabled.
      it "includes a #report_status element in the turbo_stream response body" do
        post workspace_app_reports_path(workspace, the_app), as: :turbo_stream
        wrapper = Nokogiri::HTML::Document.parse(response.body).at_css("#report_status")
        expect(wrapper).to be_present
      end

      it "renders all three buttons disabled inside the turbo_stream #report_status element" do
        post workspace_app_reports_path(workspace, the_app), as: :turbo_stream
        buttons = Nokogiri::HTML::Document.parse(response.body).css("#report_status button")
        expect(buttons.size).to eq(3)
        expect(buttons.all? { |button| button["disabled"].present? }).to be true
      end

      it "sets data-report-status-had-completed-report-value to false on a first-ever report attempt" do
        post workspace_app_reports_path(workspace, the_app), as: :turbo_stream
        wrapper = Nokogiri::HTML::Document.parse(response.body).at_css("#report_status")
        expect(wrapper["data-report-status-had-completed-report-value"]).to eq("false")
      end

      context "when a completed report already exists" do
        it "sets data-report-status-had-completed-report-value to true" do
          create(:report, app: the_app, status: :complete)
          post workspace_app_reports_path(workspace, the_app), as: :turbo_stream
          wrapper = Nokogiri::HTML::Document.parse(response.body).at_css("#report_status")
          expect(wrapper["data-report-status-had-completed-report-value"]).to eq("true")
        end
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
  # Re-analyze / Refresh button visibility on the app show page
  #
  # BRA-71 wires these buttons up to the same `policy(@app).generate_report?`
  # check that already gates the "Generate Report" button — admin/super_admin
  # only, with no dependency on whether a completed (or any) report exists.
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

    context "when signed in as an admin and no completed report exists" do
      before do
        make_member(role: :admin)
        sign_in user
        create(:report, app: the_app, status: :pending)
      end

      it "shows the Re-analyze existing reviews button" do
        get workspace_app_path(workspace, the_app)
        expect(response.body).to include("Re-analyze existing reviews")
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

  describe "GET /workspaces/:workspace_id/apps/:id — Refresh reviews + re-analyze button visibility" do
    context "when signed in as an admin and a completed report exists" do
      before do
        make_member(role: :admin)
        sign_in user
        create(:report, app: the_app, status: :complete)
      end

      it "shows the Refresh reviews + re-analyze button" do
        get workspace_app_path(workspace, the_app)
        expect(response.body).to include("Refresh reviews + re-analyze")
      end
    end

    context "when signed in as a super_admin and a completed report exists" do
      before do
        make_member(role: :super_admin)
        sign_in user
        create(:report, app: the_app, status: :complete)
      end

      it "shows the Refresh reviews + re-analyze button" do
        get workspace_app_path(workspace, the_app)
        expect(response.body).to include("Refresh reviews + re-analyze")
      end
    end

    context "when signed in as an admin and no completed report exists" do
      before do
        make_member(role: :admin)
        sign_in user
        create(:report, app: the_app, status: :pending)
      end

      it "shows the Refresh reviews + re-analyze button" do
        get workspace_app_path(workspace, the_app)
        expect(response.body).to include("Refresh reviews + re-analyze")
      end
    end

    context "when signed in as a collaborator and a completed report exists" do
      before do
        make_member(role: :collaborator)
        sign_in user
        create(:report, app: the_app, status: :complete)
      end

      it "hides the Refresh reviews + re-analyze button" do
        get workspace_app_path(workspace, the_app)
        expect(response.body).not_to include("Refresh reviews + re-analyze")
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

      # BRA-77
      it "sets report_type to reanalyze on the new report" do
        existing_report
        post reanalyze_workspace_app_report_path(workspace, the_app, existing_report)
        expect(Report.order(:created_at).last.report_type).to eq("reanalyze")
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

  # ---------------------------------------------------------------------------
  # POST /workspaces/:workspace_id/apps/:app_id/reports/reanalyze (collection route, no report id)
  # ---------------------------------------------------------------------------
  describe "POST /workspaces/:workspace_id/apps/:app_id/reports/reanalyze" do
    context "when signed in as an admin" do
      before do
        make_member(role: :admin)
        sign_in user
      end

      it "creates a new Report record" do
        expect {
          post reanalyze_workspace_app_reports_path(workspace, the_app)
        }.to change(Report, :count).by(1)
      end

      it "sets the new report's status to pending" do
        post reanalyze_workspace_app_reports_path(workspace, the_app)
        expect(Report.last.status).to eq("pending")
      end

      it "sets generated_by to the current user on the new report" do
        post reanalyze_workspace_app_reports_path(workspace, the_app)
        expect(Report.last.generated_by).to eq(user)
      end

      # BRA-77
      it "sets report_type to reanalyze on the new report" do
        post reanalyze_workspace_app_reports_path(workspace, the_app)
        expect(Report.last.report_type).to eq("reanalyze")
      end

      it "enqueues a ReportJob with skip_scraping: true for the new report" do
        expect {
          post reanalyze_workspace_app_reports_path(workspace, the_app)
        }.to have_enqueued_job(ReportJob).with { |report_id, **kwargs|
          expect(report_id).to eq(Report.last.id)
          expect(kwargs).to eq(skip_scraping: true)
        }
      end

      it "returns a turbo_stream response" do
        post reanalyze_workspace_app_reports_path(workspace, the_app), as: :turbo_stream
        expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
      end

      # BRA-75
      it "renders all three buttons disabled inside a #report_status element in the turbo_stream response" do
        post reanalyze_workspace_app_reports_path(workspace, the_app), as: :turbo_stream
        buttons = Nokogiri::HTML::Document.parse(response.body).css("#report_status button")
        expect(buttons.size).to eq(3)
        expect(buttons.all? { |button| button["disabled"].present? }).to be true
      end

      it "sets data-report-status-had-completed-report-value to true when a completed report already existed" do
        create(:report, app: the_app, status: :complete)
        post reanalyze_workspace_app_reports_path(workspace, the_app), as: :turbo_stream
        wrapper = Nokogiri::HTML::Document.parse(response.body).at_css("#report_status")
        expect(wrapper["data-report-status-had-completed-report-value"]).to eq("true")
      end
    end

    context "when signed in as a super_admin" do
      before do
        make_member(role: :super_admin)
        sign_in user
      end

      it "creates a new Report record" do
        expect {
          post reanalyze_workspace_app_reports_path(workspace, the_app)
        }.to change(Report, :count).by(1)
      end
    end

    context "when signed in as a collaborator" do
      before do
        make_member(role: :collaborator)
        sign_in user
      end

      it "returns 403 Forbidden" do
        post reanalyze_workspace_app_reports_path(workspace, the_app)
        expect(response).to have_http_status(:forbidden)
      end

      it "does not create a new Report record" do
        expect {
          post reanalyze_workspace_app_reports_path(workspace, the_app)
        }.not_to change(Report, :count)
      end
    end

    context "when not signed in" do
      it "redirects to sign in" do
        post reanalyze_workspace_app_reports_path(workspace, the_app)
        expect(response).to redirect_to(sign_in_path)
      end

      it "does not create a new Report record" do
        expect {
          post reanalyze_workspace_app_reports_path(workspace, the_app)
        }.not_to change(Report, :count)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /workspaces/:workspace_id/apps/:app_id/reports (index)
  # ---------------------------------------------------------------------------
  describe "GET .../reports (index)" do
    context "when signed in as a collaborator" do
      let!(:oldest_complete) do
        create(:report, app: the_app, status: :complete, created_at: 3.days.ago, generated_by: user,
                        total_reviews_analyzed: 10, app_store_reviews_count: 6, play_store_reviews_count: 4)
      end
      let!(:newest_complete) do
        create(:report, app: the_app, status: :complete, created_at: 1.day.ago, generated_by: user,
                        total_reviews_analyzed: 20, app_store_reviews_count: 15, play_store_reviews_count: 5)
      end
      let!(:pending_report) { create(:report, app: the_app, status: :pending, created_at: 2.days.ago) }
      let!(:failed_report) { create(:report, app: the_app, status: :failed, created_at: 2.days.ago) }

      before do
        make_member(role: :collaborator)
        sign_in user
      end

      it "returns 200 OK" do
        get workspace_app_reports_path(workspace, the_app)
        expect(response).to have_http_status(:ok)
      end

      it "excludes the pending report's link" do
        get workspace_app_reports_path(workspace, the_app)
        expect(response.body).not_to include(workspace_app_report_path(workspace, the_app, pending_report))
      end

      it "excludes the failed report's link" do
        get workspace_app_reports_path(workspace, the_app)
        expect(response.body).not_to include(workspace_app_report_path(workspace, the_app, failed_report))
      end

      it "lists complete reports in reverse chronological order" do
        get workspace_app_reports_path(workspace, the_app)
        newest_index = response.body.index(workspace_app_report_path(workspace, the_app, newest_complete))
        oldest_index = response.body.index(workspace_app_report_path(workspace, the_app, oldest_complete))
        expect(newest_index).to be < oldest_index
      end

      it "links each report to its show page" do
        get workspace_app_reports_path(workspace, the_app)
        expect(response.body).to include(workspace_app_report_path(workspace, the_app, newest_complete))
      end

      it "renders the generated_by user's name" do
        get workspace_app_reports_path(workspace, the_app)
        expect(response.body).to include(CGI.escapeHTML(user.name))
      end

      it "renders the total reviews analyzed" do
        get workspace_app_reports_path(workspace, the_app)
        expect(response.body).to include("20 reviews analyzed")
      end

      it "renders the store breakdown counts" do
        get workspace_app_reports_path(workspace, the_app)
        expect(response.body).to include("App Store: 15 / Play Store: 5")
      end

      # BRA-77 — default report_type for existing/backfilled reports is generate
      it "renders a Generate badge for reports with no report_type explicitly set" do
        get workspace_app_reports_path(workspace, the_app)
        doc = Nokogiri::HTML::Document.parse(response.body)
        badges = doc.css(".report-type-badge")
        expect(badges).not_to be_empty
        expect(badges.all? { |badge| badge.text.strip == "Generate" }).to be true
      end
    end

    context "with reports of each report_type" do
      let!(:generate_report) do
        create(:report, app: the_app, status: :complete, report_type: :generate, generated_by: user)
      end
      let!(:refresh_report) do
        create(:report, app: the_app, status: :complete, report_type: :refresh, generated_by: user)
      end
      let!(:reanalyze_report) do
        create(:report, app: the_app, status: :complete, report_type: :reanalyze, generated_by: user)
      end

      before do
        make_member(role: :collaborator)
        sign_in user
      end

      it "renders a Generate badge for a generate report" do
        get workspace_app_reports_path(workspace, the_app)
        doc = Nokogiri::HTML::Document.parse(response.body)
        badge = doc.at_css(".report-type-badge-generate")
        expect(badge.text.strip).to eq("Generate")
      end

      it "renders a Refresh badge for a refresh report" do
        get workspace_app_reports_path(workspace, the_app)
        doc = Nokogiri::HTML::Document.parse(response.body)
        badge = doc.at_css(".report-type-badge-refresh")
        expect(badge.text.strip).to eq("Refresh")
      end

      it "renders a Reanalyze badge for a reanalyze report" do
        get workspace_app_reports_path(workspace, the_app)
        doc = Nokogiri::HTML::Document.parse(response.body)
        badge = doc.at_css(".report-type-badge-reanalyze")
        expect(badge.text.strip).to eq("Reanalyze")
      end
    end

    context "when there are no completed reports" do
      before do
        make_member(role: :admin)
        sign_in user
        create(:report, app: the_app, status: :pending)
      end

      it "shows the empty state message" do
        get workspace_app_reports_path(workspace, the_app)
        expect(response.body).to include("No reports yet.")
      end
    end

    context "when the user has no membership in the workspace" do
      before { sign_in user }

      it "returns 404 Not Found" do
        get workspace_app_reports_path(workspace, the_app)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when not signed in" do
      it "redirects to sign in" do
        get workspace_app_reports_path(workspace, the_app)
        expect(response).to redirect_to(sign_in_path)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /workspaces/:workspace_id/apps/:app_id/reports/:id/refresh
  # ---------------------------------------------------------------------------
  describe "POST /workspaces/:workspace_id/apps/:app_id/reports/:id/refresh" do
    let(:existing_report) { create(:report, app: the_app, status: :complete) }

    context "when signed in as an admin" do
      before do
        make_member(role: :admin)
        sign_in user
      end

      it "creates a new Report record" do
        existing_report
        expect {
          post refresh_workspace_app_report_path(workspace, the_app, existing_report)
        }.to change(Report, :count).by(1)
      end

      it "does not modify the existing report's status" do
        existing_report
        post refresh_workspace_app_report_path(workspace, the_app, existing_report)
        expect(existing_report.reload.status).to eq("complete")
      end

      it "does not modify the existing report's updated_at timestamp" do
        existing_report
        original_updated_at = existing_report.updated_at
        post refresh_workspace_app_report_path(workspace, the_app, existing_report)
        expect(existing_report.reload.updated_at).to eq(original_updated_at)
      end

      it "sets the new report's status to pending" do
        existing_report
        post refresh_workspace_app_report_path(workspace, the_app, existing_report)
        expect(Report.order(:created_at).last.status).to eq("pending")
      end

      it "sets generated_by to the current user on the new report" do
        existing_report
        post refresh_workspace_app_report_path(workspace, the_app, existing_report)
        expect(Report.order(:created_at).last.generated_by).to eq(user)
      end

      # BRA-77
      it "sets report_type to refresh on the new report" do
        existing_report
        post refresh_workspace_app_report_path(workspace, the_app, existing_report)
        expect(Report.order(:created_at).last.report_type).to eq("refresh")
      end

      it "enqueues a ReportJob with the new report's id and no skip_scraping kwarg" do
        existing_report
        post refresh_workspace_app_report_path(workspace, the_app, existing_report)
        report = Report.order(:created_at).last
        enqueued = ActiveJob::Base.queue_adapter.enqueued_jobs.find { |j| j["job_class"] == "ReportJob" }
        expect(enqueued["arguments"]).to eq([report.id])
      end

      it "returns a turbo_stream response" do
        existing_report
        post refresh_workspace_app_report_path(workspace, the_app, existing_report), as: :turbo_stream
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
          post refresh_workspace_app_report_path(workspace, the_app, existing_report)
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
        post refresh_workspace_app_report_path(workspace, the_app, existing_report)
        expect(response).to have_http_status(:forbidden)
      end

      it "does not create a new Report record" do
        existing_report
        expect {
          post refresh_workspace_app_report_path(workspace, the_app, existing_report)
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
        post refresh_workspace_app_report_path(workspace, the_app, foreign_report)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when not signed in" do
      it "redirects to sign in" do
        existing_report
        post refresh_workspace_app_report_path(workspace, the_app, existing_report)
        expect(response).to redirect_to(sign_in_path)
      end

      it "does not create a new Report record" do
        existing_report
        expect {
          post refresh_workspace_app_report_path(workspace, the_app, existing_report)
        }.not_to change(Report, :count)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /workspaces/:workspace_id/apps/:app_id/reports/refresh (collection route, no report id)
  # ---------------------------------------------------------------------------
  describe "POST /workspaces/:workspace_id/apps/:app_id/reports/refresh" do
    context "when signed in as an admin" do
      before do
        make_member(role: :admin)
        sign_in user
      end

      it "creates a new Report record" do
        expect {
          post refresh_workspace_app_reports_path(workspace, the_app)
        }.to change(Report, :count).by(1)
      end

      it "sets the new report's status to pending" do
        post refresh_workspace_app_reports_path(workspace, the_app)
        expect(Report.last.status).to eq("pending")
      end

      it "sets generated_by to the current user on the new report" do
        post refresh_workspace_app_reports_path(workspace, the_app)
        expect(Report.last.generated_by).to eq(user)
      end

      # BRA-77
      it "sets report_type to refresh on the new report" do
        post refresh_workspace_app_reports_path(workspace, the_app)
        expect(Report.last.report_type).to eq("refresh")
      end

      it "enqueues a ReportJob with the new report's id and no skip_scraping kwarg" do
        post refresh_workspace_app_reports_path(workspace, the_app)
        report = Report.last
        enqueued = ActiveJob::Base.queue_adapter.enqueued_jobs.find { |j| j["job_class"] == "ReportJob" }
        expect(enqueued["arguments"]).to eq([report.id])
      end

      it "returns a turbo_stream response" do
        post refresh_workspace_app_reports_path(workspace, the_app), as: :turbo_stream
        expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
      end

      # BRA-75
      it "renders all three buttons disabled inside a #report_status element in the turbo_stream response" do
        post refresh_workspace_app_reports_path(workspace, the_app), as: :turbo_stream
        buttons = Nokogiri::HTML::Document.parse(response.body).css("#report_status button")
        expect(buttons.size).to eq(3)
        expect(buttons.all? { |button| button["disabled"].present? }).to be true
      end

      it "sets data-report-status-had-completed-report-value to true when a completed report already existed" do
        create(:report, app: the_app, status: :complete)
        post refresh_workspace_app_reports_path(workspace, the_app), as: :turbo_stream
        wrapper = Nokogiri::HTML::Document.parse(response.body).at_css("#report_status")
        expect(wrapper["data-report-status-had-completed-report-value"]).to eq("true")
      end
    end

    context "when signed in as a super_admin" do
      before do
        make_member(role: :super_admin)
        sign_in user
      end

      it "creates a new Report record" do
        expect {
          post refresh_workspace_app_reports_path(workspace, the_app)
        }.to change(Report, :count).by(1)
      end
    end

    context "when signed in as a collaborator" do
      before do
        make_member(role: :collaborator)
        sign_in user
      end

      it "returns 403 Forbidden" do
        post refresh_workspace_app_reports_path(workspace, the_app)
        expect(response).to have_http_status(:forbidden)
      end

      it "does not create a new Report record" do
        expect {
          post refresh_workspace_app_reports_path(workspace, the_app)
        }.not_to change(Report, :count)
      end
    end

    context "when not signed in" do
      it "redirects to sign in" do
        post refresh_workspace_app_reports_path(workspace, the_app)
        expect(response).to redirect_to(sign_in_path)
      end

      it "does not create a new Report record" do
        expect {
          post refresh_workspace_app_reports_path(workspace, the_app)
        }.not_to change(Report, :count)
      end
    end
  end
end
