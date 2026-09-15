# frozen_string_literal: true

FactoryBot.define do
  factory :app do
    workspace
    association :created_by, factory: :user
    name { Faker::App.name }
    app_store_id { SecureRandom.hex(4) }
    play_store_id { nil }

    trait :with_icp do
      icp do
        {
          "primary_segment" => "busy freelancers",
          "confidence" => "high",
          "signals" => [
            {
              "quote" => "I run my own freelance business and this helps me track expenses on the go",
              "role_hint" => "freelancer"
            }
          ]
        }
      end
      icp_generated_at { Time.current }
      icp_model { "gemini-2.5-flash" }
      icp_input_tokens { 1200 }
      icp_output_tokens { 350 }
      icp_cost_usd { 0.001235 }
      icp_usage_metadata { { "promptTokenCount" => 1200, "candidatesTokenCount" => 350, "totalTokenCount" => 1550 } }
    end

    trait :icp_declined do
      icp { nil }
      icp_declined_reason { "Not enough reviews to determine a reliable ICP" }
      icp_generated_at { Time.current }
      icp_model { "gemini-2.5-flash" }
      icp_input_tokens { 900 }
      icp_output_tokens { 40 }
      icp_cost_usd { 0.000370 }
      icp_usage_metadata { { "promptTokenCount" => 900, "candidatesTokenCount" => 40, "totalTokenCount" => 940 } }
    end
  end
end
