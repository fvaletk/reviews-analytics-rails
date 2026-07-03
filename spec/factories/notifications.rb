# frozen_string_literal: true

FactoryBot.define do
  factory :notification do
    user
    workspace
    report
    message { "Report is ready." }
  end
end
