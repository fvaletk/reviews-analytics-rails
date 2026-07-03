# frozen_string_literal: true

class ReportPolicy < ApplicationPolicy
  # record is a Report instance

  def show?
    member?
  end

  class Scope < Scope
    def resolve
      scope.joins(app: { workspace: :workspace_memberships })
           .where(workspace_memberships: { user: user })
    end
  end

  private

  def membership
    @membership ||= user.workspace_memberships.find_by(workspace: record.app.workspace)
  end

  def member?
    membership.present?
  end
end
