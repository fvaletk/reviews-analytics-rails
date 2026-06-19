# frozen_string_literal: true

class Report < ApplicationRecord
  belongs_to :app
  belongs_to :generated_by, class_name: "User", foreign_key: :generated_by_user_id

  enum :status, { pending: 0, fetching: 1, analyzing: 2, complete: 3, failed: 4 }

  validates :status, presence: true
end
