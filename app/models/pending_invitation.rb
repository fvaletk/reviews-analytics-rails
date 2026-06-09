# frozen_string_literal: true

class PendingInvitation < ApplicationRecord
  belongs_to :workspace
  belongs_to :invited_by_user, class_name: "User", foreign_key: :invited_by_user_id, optional: true

  enum :role, { collaborator: 0, admin: 1, super_admin: 2 }

  validates :email, presence: true
  validates :role, presence: true
  validates :email, uniqueness: { scope: :workspace_id, message: "has already been invited to this workspace" }
end
