# frozen_string_literal: true

class App < ApplicationRecord
  belongs_to :workspace
  belongs_to :created_by, class_name: "User", foreign_key: :created_by_user_id

  attr_accessor :app_store_url, :play_store_url

  validates :name, presence: true
  validates :workspace, presence: true
  validates :created_by, presence: true
  validate :at_least_one_store_id

  private

  def at_least_one_store_id
    return if app_store_id.present? || play_store_id.present?

    errors.add(:base, "must have at least one of app_store_id or play_store_id")
  end
end
