# frozen_string_literal: true

FactoryBot.define do
  factory :workspace do
    name { Faker::Company.name }
  end
end
