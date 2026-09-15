# frozen_string_literal: true

require "rails_helper"

RSpec.describe IcpPromptBuilder do
  describe ".build" do
    let(:reviews) { build_stubbed_list(:review, 2) }
    let(:prompt) { described_class.build(reviews: reviews) }

    it "returns a String" do
      expect(prompt).to be_a(String)
    end

    it "grants explicit permission to decline when no self-identification is present" do
      expect(prompt).to include("Do not infer an audience from what the app appears to do")
    end

    it "states that an empty answer is correct and expected" do
      expect(prompt).to include("An empty answer is correct and expected")
    end

    it "requires quotes to be verbatim" do
      expect(prompt).to match(/VERBATIM/)
      expect(prompt).to include("Never paraphrase or invent a quote")
    end

    it "instructs that a decline must carry an empty signals array" do
      expect(prompt).to include("a decline cannot carry evidence")
    end

    it "includes the schema keys" do
      expect(prompt).to include("primary_segment")
      expect(prompt).to include("confidence")
      expect(prompt).to include("signals")
      expect(prompt).to include("declined_reason")
      expect(prompt).to include("role_hint")
    end

    it "includes the exact 'Return only valid JSON' instruction" do
      expect(prompt).to include("Return only valid JSON. No markdown. No explanation.")
    end

    it "does not include a rating distribution" do
      expect(prompt).not_to include("Rating distribution")
      expect(prompt).not_to include("total reviews")
    end

    it "does not accept a distribution argument" do
      expect { described_class.build(reviews: reviews, distribution: {}) }.to raise_error(ArgumentError)
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
    end
  end
end
