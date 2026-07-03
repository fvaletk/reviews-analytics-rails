# frozen_string_literal: true

class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :workspace
  belongs_to :report

  validates :message, presence: true

  scope :unread, -> { where(read_at: nil) }

  def self.unread_count_for(user)
    unread.where(user: user).count
  end
end
