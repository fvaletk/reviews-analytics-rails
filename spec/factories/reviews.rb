# frozen_string_literal: true

FactoryBot.define do
  factory :review do
    app
    store { :app_store }
    external_id { SecureRandom.hex(8) }
    author { Faker::Name.name }
    rating { rand(1..5) }
    title { Faker::Lorem.sentence }
    body { Faker::Lorem.paragraph }
    reviewed_at { 1.week.ago }
    fetched_at { Time.current }
  end
end
