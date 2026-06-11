# frozen_string_literal: true

class WorkspacePolicy < ApplicationPolicy
  def create?
    user.present?
  end

  def show?
    member?
  end

  def update?
    super_admin?
  end

  def destroy?
    super_admin?
  end

  def invite?
    super_admin?
  end

  def create_app?
    admin? || super_admin?
  end

  def generate_report?
    admin? || super_admin?
  end

  class Scope < Scope
    def resolve
      scope.joins(:workspace_memberships)
           .where(workspace_memberships: { user_id: user.id })
    end
  end

  private

  def membership
    @membership ||= user.workspace_memberships.find_by(workspace: record)
  end

  def member?
    membership.present?
  end

  def admin?
    membership&.admin?
  end

  def super_admin?
    membership&.super_admin?
  end
end
