# frozen_string_literal: true

require "rails_helper"

RSpec.describe LlmPromptBuilder do
  describe ".build" do
    let(:reviews) { build_stubbed_list(:review, 2) }

    it "returns a String" do
      expect(described_class.build(reviews: reviews)).to be_a(String)
    end

    it "includes the review count as a substring" do
      prompt = described_class.build(reviews: reviews)

      expect(prompt).to include("#{reviews.size} app reviews")
    end

    context "schema section names and fields" do
      let(:prompt) { described_class.build(reviews: reviews) }

      it "includes summary" do
        expect(prompt).to include("summary")
      end

      it "includes pain_points with its nested fields" do
        expect(prompt).to include("pain_points")
        expect(prompt).to include("severity")
        expect(prompt).to include("frequency")
        expect(prompt).to include("evidence_count")
      end

      it "includes complaints" do
        expect(prompt).to include("complaints")
      end

      it "includes feature_requests with its nested fields" do
        expect(prompt).to include("feature_requests")
        expect(prompt).to include("category")
        expect(prompt).to include("items")
        expect(prompt).to include("demand")
      end

      it "includes strengths" do
        expect(prompt).to include("strengths")
      end

      it "includes opportunities with its rationale field" do
        expect(prompt).to include("opportunities")
        expect(prompt).to include("rationale")
      end
    end

    context "valid value enumerations" do
      let(:prompt) { described_class.build(reviews: reviews) }

      it "includes valid severity values" do
        expect(prompt).to include("critical, high, medium, low")
      end

      it "includes valid frequency values" do
        expect(prompt).to include("frequency: high, medium, low")
      end

      it "includes valid demand values" do
        expect(prompt).to include("demand: high, medium, low")
      end
    end

    it "includes the exact 'Return only valid JSON' instruction" do
      prompt = described_class.build(reviews: reviews)

      expect(prompt).to include("Return only valid JSON. No markdown. No explanation.")
    end

    context "review serialization" do
      let(:review) do
        build_stubbed(
          :review,
          store: :play_store,
          rating: 4,
          title: "Distinctive Title Text",
          body: "Distinctive body content describing the review.",
          author: "Distinctive Author Name",
          reviewed_at: 3.days.ago
        )
      end
      let(:prompt) { described_class.build(reviews: [ review ]) }

      it "includes the review's store" do
        expect(prompt).to include("play_store")
      end

      it "includes the review's rating" do
        expect(prompt).to include("\"rating\":4")
      end

      it "includes the review's title" do
        expect(prompt).to include("Distinctive Title Text")
      end

      it "includes the review's body" do
        expect(prompt).to include("Distinctive body content describing the review.")
      end

      it "does not include the review's author" do
        expect(prompt).not_to include("Distinctive Author Name")
      end

      it "does not include the review's reviewed_at timestamp" do
        expect(prompt).not_to include(review.reviewed_at.to_s)
      end
    end
  end
end
