# frozen_string_literal: true

class IcpsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_workspace
  before_action :set_app

  # Scoped exception to the global 404-on-authorization-failure convention:
  # this shares a screen (and a button rail) with ReportsController, which
  # already returns 403 for unauthorized report generation — a 404 here for
  # the same generate_report? check would be an inconsistent-looking bug.
  rescue_from Pundit::NotAuthorizedError, with: :handle_not_authorized

  def create
    authorize @app, :generate_report?

    IcpExtractionJob.perform_later(@app.id, force: true)

    respond_to do |format|
      format.turbo_stream
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
