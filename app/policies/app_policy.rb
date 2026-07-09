# frozen_string_literal: true

class AppPolicy < ApplicationPolicy
  # record is an App instance

  def show?
    member?
  end

  def create?
    admin? || super_admin?
  end

  def new?
    create?
  end

  def update?
    admin? || super_admin?
  end

  def edit?
    update?
  end

  def destroy?
    admin? || super_admin?
  end

  def generate_report?
    admin? || super_admin?
  end

  class Scope < Scope
    def resolve
      scope.joins(workspace: :workspace_memberships)
           .where(workspace_memberships: { user: user })
    end
  end

  private

  def membership
    @membership ||= user.workspace_memberships.find_by(workspace: record.workspace)
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
