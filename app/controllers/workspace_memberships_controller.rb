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

  def destroy
    authorize @workspace, :invite?

    @membership_to_remove = @workspace.workspace_memberships.find(params[:id])

    sole_super_admin = @workspace.workspace_memberships.where(role: :super_admin).count == 1 &&
                       @membership_to_remove.super_admin? &&
                       @membership_to_remove.user_id == current_user.id

    if sole_super_admin
      redirect_to new_workspace_membership_path(@workspace),
                  alert: "Cannot remove the sole super admin."
      return
    end

    @membership_to_remove.destroy!
    redirect_to new_workspace_membership_path(@workspace),
                notice: "Member removed successfully."
  end

  private

  def set_workspace
    @workspace = Workspace.find(params[:workspace_id])
  end
end
