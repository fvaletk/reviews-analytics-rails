# frozen_string_literal: true

class Review < ApplicationRecord
  belongs_to :app

  enum :store, { app_store: 0, play_store: 1 }

  validates :store, presence: true
  validates :external_id, presence: true
end
