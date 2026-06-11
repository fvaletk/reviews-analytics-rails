# frozen_string_literal: true

FactoryBot.define do
  factory :app do
    workspace
    association :created_by, factory: :user
    name { Faker::App.name }
    app_store_id { SecureRandom.hex(4) }
    play_store_id { nil }
  end
end
