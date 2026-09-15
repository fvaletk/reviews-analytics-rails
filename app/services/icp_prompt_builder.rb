# frozen_string_literal: true

class IcpPromptBuilder
  SCHEMA_DESCRIPTION = <<~SCHEMA
    {
      "primary_segment": "string or null — the single ideal customer profile segment, e.g. 'freelance graphic designers' or 'small restaurant owners'",
      "confidence": "high | medium | low, or null",
      "signals": [
        {
          "quote": "string — a VERBATIM excerpt copied exactly from one of the supplied reviews",
          "role_hint": "string — free text describing who said it, in their own words or a short paraphrase of their self-identification"
        }
      ],
      "declined_reason": "string or null — why no primary_segment could be determined"
    }
  SCHEMA

  def self.build(reviews:)
    serialized_reviews = serialize_reviews(reviews)

    <<~PROMPT
      You are a competitive intelligence analyst. Your task is to infer the app's Ideal Customer Profile (ICP) — who actually uses this app — based ONLY on first-person self-identification found in the reviews below.

      A review only counts as a signal if the reviewer says what they do, what they manage, or who they are (their role, job, or identity) — not merely what they did in the app or how they feel about it.

      If the reviews contain no first-person self-identification — no reviewer saying what they do, what they manage, or who they are — return primary_segment: null and put what was missing in declined_reason. Do not infer an audience from what the app appears to do. An empty answer is correct and expected for apps whose reviewers never identify themselves.

      Rules:
      - Every "quote" must be VERBATIM — copied exactly, word for word, from one of the reviews below. Never paraphrase or invent a quote.
      - "role_hint" is free text, not a controlled vocabulary — describe the role or identity in your own words.
      - Include at most 15 signals, the strongest and clearest ones.
      - If you decline (primary_segment is null), "signals" must be an empty array — a decline cannot carry evidence.

      Reviews (JSON array of {store, rating, title, body}):
      #{serialized_reviews.to_json}

      Return a single JSON object matching exactly the following schema. Do not add, rename, or omit any keys.

      Schema:
      #{SCHEMA_DESCRIPTION}

      Valid values:
      - confidence: high, medium, low, or null

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
