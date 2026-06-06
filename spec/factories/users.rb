# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    name { Faker::Name.name }
    email { Faker::Internet.unique.email }
    provider { "google_oauth2" }
    uid { SecureRandom.hex }
  end
end
