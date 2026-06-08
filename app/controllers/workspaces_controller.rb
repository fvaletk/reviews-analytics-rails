# frozen_string_literal: true

class WorkspacesController < ApplicationController
  before_action :authenticate_user!

  def new
    @workspace = Workspace.new
    authorize Workspace
  end

  def create
    authorize Workspace
    workspace = Workspaces::CreateWorkspaceService.call(
      name: params.dig(:workspace, :name),
      user: current_user
    )
    redirect_to workspace_path(workspace)
  rescue Workspaces::CreateWorkspaceService::Error
    @workspace = Workspace.new(name: params.dig(:workspace, :name))
    @workspace.valid?
    render :new, status: :unprocessable_entity
  end

  def show
    @workspace = Workspace.find(params[:id])
    authorize @workspace
  end
end
