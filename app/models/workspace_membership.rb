# frozen_string_literal: true

class WorkspaceMembership < ApplicationRecord
  belongs_to :user
  belongs_to :workspace
  belongs_to :invited_by_user, class_name: "User", foreign_key: :invited_by_user_id, optional: true

  enum :role, { collaborator: 0, admin: 1, super_admin: 2 }

  validates :role, presence: true
end
