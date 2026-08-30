# frozen_string_literal: true

class LlmPromptBuilder
  SCHEMA_DESCRIPTION = <<~SCHEMA
    {
      "summary": "string — 2-3 sentence executive summary",

      "pain_points": [
        {
          "title": "string",
          "severity": "critical | high | medium | low",
          "frequency": "high | medium | low",
          "description": "string",
          "evidence_count": 0
        }
      ],

      "complaints": [
        {
          "title": "string",
          "description": "string",
          "frequency": "high | medium | low"
        }
      ],

      "feature_requests": [
        {
          "category": "string",
          "items": [
            {
              "title": "string",
              "description": "string",
              "demand": "high | medium | low"
            }
          ]
        }
      ],

      "strengths": [
        {
          "title": "string",
          "description": "string"
        }
      ],

      "opportunities": [
        {
          "title": "string",
          "description": "string",
          "rationale": "string"
        }
      ]
    }
  SCHEMA

  def self.build(reviews:, distribution:)
    serialized_reviews = serialize_reviews(reviews)
    total = distribution.values.sum

    <<~PROMPT
      You are a competitive intelligence analyst. Analyze the following #{serialized_reviews.size} app reviews to identify patterns — pain points, complaints, feature requests, strengths, and opportunities — for competitive intelligence purposes.

      This app has #{total} total reviews. Rating distribution: 1★: #{distribution["1"]}, 2★: #{distribution["2"]}, 3★: #{distribution["3"]}, 4★: #{distribution["4"]}, 5★: #{distribution["5"]}, unrated: #{distribution["unrated"]}.

      The #{serialized_reviews.size} reviews below are a selected sample chosen to surface substantive, diverse feedback — not the full corpus. Base `frequency` and `evidence_count` on the rating distribution stated above, not on how often something appears in this sample.

      Reviews (JSON array of {store, rating, title, body}):
      #{serialized_reviews.to_json}

      Return a single JSON object matching exactly the following schema. Do not add, rename, or omit any keys.

      Schema:
      #{SCHEMA_DESCRIPTION}

      Valid values:
      - severity: critical, high, medium, low
      - frequency: high, medium, low
      - demand: high, medium, low

      Return only valid JSON. No markdown. No explanation. No preamble. No markdown fences. No text before or after the JSON object.
    PROMPT
  end

  def self.serialize_reviews(reviews)
    reviews.map do |review|
      {
        store: review.store,
        rating: review.rating,
        title: review.title,
        body: review.body
      }
    end
  end
  private_class_method :serialize_reviews
end
