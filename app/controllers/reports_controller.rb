# frozen_string_literal: true

class ReportsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_workspace
  before_action :set_app

  # Scoped exception to the global 404-on-authorization-failure convention:
  # this ticket explicitly requires a 403 for unauthorized report generation.
  rescue_from Pundit::NotAuthorizedError, with: :handle_not_authorized

  def index
    authorize @app, :show?
    @reports = @app.reports.where(status: :complete).includes(:generated_by).order(created_at: :desc)
  end

  def create
    authorize @app, :generate_report?

    @report = @app.reports.create!(status: :pending, generated_by: current_user)
    ReportJob.perform_later(@report.id)

    respond_to do |format|
      format.turbo_stream
    end
  end

  def show
    @report = @app.reports.find(params[:id])
    authorize @report
  end

  def reanalyze
    @app.reports.find(params[:id])
    authorize @app, :generate_report?

    @report = @app.reports.create!(status: :pending, generated_by: current_user)
    ReportJob.perform_later(@report.id, skip_scraping: true)

    respond_to do |format|
      format.turbo_stream { render :create }
    end
  end

  def refresh
    @app.reports.find(params[:id])
    authorize @app, :generate_report?

    @report = @app.reports.create!(status: :pending, generated_by: current_user)
    ReportJob.perform_later(@report.id)

    respond_to do |format|
      format.turbo_stream { render :create }
    end
  end

  private

  def set_workspace
    @workspace = Workspace.joins(:workspace_memberships)
                          .find_by!(id: params[:workspace_id],
                                    workspace_memberships: { user_id: current_user.id })
  end

  def set_app
    @app = @workspace.apps.find(params[:app_id])
  end

  def handle_not_authorized
    head :forbidden
  end
end
