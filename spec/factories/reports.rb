# frozen_string_literal: true

FactoryBot.define do
  factory :report do
    app
    association :generated_by, factory: :user
    status { :pending }
    total_reviews_analyzed { 0 }
  end
end
