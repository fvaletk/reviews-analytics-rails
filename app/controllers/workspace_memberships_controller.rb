# frozen_string_literal: true

class WorkspaceMembershipsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_workspace

  def new
    authorize @workspace, :invite?
    @membership = WorkspaceMembership.new
  end

  def create
    authorize @workspace, :invite?

    Workspaces::InviteMemberService.call(
      workspace:  @workspace,
      email:      params.dig(:workspace_membership, :email),
      role:       params.dig(:workspace_membership, :role),
      invited_by: current_user
    )

    redirect_to new_workspace_membership_path(@workspace),
                notice: "Invitation sent successfully."
  rescue Workspaces::InviteMemberService::Error => e
    @membership = WorkspaceMembership.new
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_entity
  end

  private

  def set_workspace
    @workspace = Workspace.find(params[:workspace_id])
  end
end
