# frozen_string_literal: true

class Workspace < ApplicationRecord
  has_many :workspace_memberships, dependent: :destroy
  has_many :users, through: :workspace_memberships

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :set_slug_from_name

  private

  def set_slug_from_name
    self.slug = name.parameterize if slug.blank? && name.present?
  end
end
