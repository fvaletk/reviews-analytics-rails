# frozen_string_literal: true

class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    skip_authorization
    @workspaces = policy_scope(Workspace).includes(:workspace_memberships).order(:name)
  end
end
