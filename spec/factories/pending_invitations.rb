# frozen_string_literal: true

FactoryBot.define do
  factory :pending_invitation do
    workspace
    association :invited_by_user, factory: :user
    email { Faker::Internet.unique.email }
    role  { :collaborator }
  end
end
