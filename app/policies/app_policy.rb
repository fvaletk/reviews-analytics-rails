# frozen_string_literal: true

class AppPolicy < ApplicationPolicy
  # record is an App instance

  def show?
    member?
  end

  def create?
    member?
  end

  def new?
    create?
  end

  private

  def membership
    @membership ||= user.workspace_memberships.find_by(workspace: record.workspace)
  end

  def member?
    membership.present?
  end
end
