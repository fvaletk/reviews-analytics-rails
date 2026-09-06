# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReviewSelector do
  let(:workspace) { create(:workspace) }
  let(:app) { create(:app, workspace: workspace) }

  def substantive_body(tag)
    "Substantive review body #{tag} with enough content to pass the noise filter."
  end

  describe "constants" do
    it "caps MAX_REVIEWS_TOTAL at 1000" do
      expect(described_class::MAX_REVIEWS_TOTAL).to eq(1000)
    end

    it "caps MAX_REVIEWS_PER_STORE at 500" do
      expect(described_class::MAX_REVIEWS_PER_STORE).to eq(500)
    end

    it "sets MIN_BODY_LENGTH to 12" do
      expect(described_class::MIN_BODY_LENGTH).to eq(12)
    end

    it "defines band shares of negative 0.45, mixed 0.25, positive 0.30" do
      expect(described_class::BANDS.transform_values { |cfg| cfg[:share] }).to eq(
        negative: 0.45, mixed: 0.25, positive: 0.30
      )
    end
  end

  describe ".select — noise filtering" do
    it "excludes a review with a nil body and counts it under filtered_out[:empty]" do
      create(:review, app: app, store: :app_store, body: nil, reviewed_at: 1.day.ago)

      result = described_class.select(Review.where(app: app))

      expect(result.metadata[:filtered_out][:empty]).to eq(1)
    end

    it "excludes a review with a blank/whitespace-only body" do
      create(:review, app: app, store: :app_store, body: "   ", reviewed_at: 1.day.ago)

      result = described_class.select(Review.where(app: app))

      expect(result.app_store).to be_empty
    end

    it "excludes a review whose normalized body is under MIN_BODY_LENGTH and counts it under filtered_out[:too_short]" do
      create(:review, app: app, store: :app_store, body: "good", reviewed_at: 1.day.ago)

      result = described_class.select(Review.where(app: app))

      expect(result.metadata[:filtered_out][:too_short]).to eq(1)
    end

    it "excludes a body that is only emoji (normalizes to nothing) as too_short" do
      create(:review, app: app, store: :app_store, body: "😀😀😀😀😀", reviewed_at: 1.day.ago)

      result = described_class.select(Review.where(app: app))

      expect(result.metadata[:filtered_out][:too_short]).to eq(1)
    end

    it "excludes an exact normalized duplicate body within the same app and store, counting it under filtered_out[:duplicate]" do
      create(:review, app: app, store: :app_store, external_id: "old", body: "This is a duplicate review body", reviewed_at: 2.days.ago)
      create(:review, app: app, store: :app_store, external_id: "new", body: "this is a DUPLICATE review body!!", reviewed_at: 1.day.ago)

      result = described_class.select(Review.where(app: app))

      expect(result.metadata[:filtered_out][:duplicate]).to eq(1)
    end

    it "keeps the most recent of two duplicate bodies" do
      create(:review, app: app, store: :app_store, external_id: "old", body: "This is a duplicate review body", reviewed_at: 2.days.ago)
      create(:review, app: app, store: :app_store, external_id: "new", body: "this is a DUPLICATE review body!!", reviewed_at: 1.day.ago)

      result = described_class.select(Review.where(app: app))

      expect(result.app_store.map(&:external_id)).to eq([ "new" ])
    end

    it "does not treat the same normalized body in a different store as a duplicate" do
      create(:review, app: app, store: :app_store, external_id: "as1", body: "this is a duplicate review body", reviewed_at: 1.day.ago)
      create(:review, app: app, store: :play_store, external_id: "ps1", body: "this is a duplicate review body", reviewed_at: 1.day.ago)

      result = described_class.select(Review.where(app: app))

      expect(result.metadata[:filtered_out][:duplicate]).to eq(0)
      expect(result.app_store.map(&:external_id)).to eq([ "as1" ])
      expect(result.play_store.map(&:external_id)).to eq([ "ps1" ])
    end

    it "does not increment filtered_out for a normal, sufficiently long, unique body" do
      create(:review, app: app, store: :app_store, body: substantive_body("ok"), reviewed_at: 1.day.ago)

      result = described_class.select(Review.where(app: app))

      expect(result.metadata[:filtered_out]).to eq(empty: 0, too_short: 0, duplicate: 0)
    end
  end

  describe ".select — normalization dedupes across case, punctuation, emoji, and whitespace" do
    it "treats bodies differing only in case, punctuation, emoji, and whitespace runs as duplicates" do
      create(:review, app: app, store: :app_store, external_id: "old", body: "Great   app, love   it!!", reviewed_at: 2.days.ago)
      create(:review, app: app, store: :app_store, external_id: "new", body: "great app love it 😀😀", reviewed_at: 1.day.ago)

      result = described_class.select(Review.where(app: app))

      expect(result.app_store.map(&:external_id)).to eq([ "new" ])
      expect(result.metadata[:filtered_out][:duplicate]).to eq(1)
    end
  end

  describe ".select — true rating distribution" do
    it "reflects GROUP BY rating over all stored reviews for the scope, including reviews later filtered out" do
      create(:review, app: app, store: :app_store, rating: 1, body: "good", reviewed_at: 1.day.ago) # too_short, filtered out
      create(:review, app: app, store: :app_store, rating: 5, body: substantive_body("a"), reviewed_at: 1.day.ago)
      create(:review, app: app, store: :app_store, rating: 5, body: substantive_body("b"), reviewed_at: 1.day.ago)
      create(:review, app: app, store: :app_store, rating: nil, body: substantive_body("c"), reviewed_at: 1.day.ago)

      result = described_class.select(Review.where(app: app))

      expect(result.metadata[:distribution]).to eq(
        "1" => 1, "2" => 0, "3" => 0, "4" => 0, "5" => 2, "unrated" => 1
      )
    end
  end

  describe "#select_for_store (band quotas, spillover, and unrated fill)" do
    subject(:select_for_store) { described_class.new(nil).send(:select_for_store, pool) }

    def review_pool(rating:, count:)
      count.times.map { |i| Review.new(rating: rating, reviewed_at: (i + 1).minutes.ago) }
    end

    context "when every band comfortably exceeds its quota" do
      let(:pool) do
        review_pool(rating: 1, count: 400) +
          review_pool(rating: 3, count: 400) +
          review_pool(rating: 5, count: 400)
      end

      let(:expected_quotas) do
        ReviewSelector::BANDS.transform_values { |cfg| (ReviewSelector::MAX_REVIEWS_PER_STORE * cfg[:share]).round }
      end

      it "selects exactly the negative band quota" do
        expect(select_for_store[:bands][:negative]).to eq(expected_quotas[:negative])
      end

      it "selects exactly the mixed band quota" do
        expect(select_for_store[:bands][:mixed]).to eq(expected_quotas[:mixed])
      end

      it "selects exactly the positive band quota" do
        expect(select_for_store[:bands][:positive]).to eq(expected_quotas[:positive])
      end

      it "selects the sum of all three quotas in total" do
        expect(select_for_store[:selected].size).to eq(expected_quotas.values.sum)
      end
    end

    context "when the negative band is underfilled relative to its quota" do
      let(:pool) do
        review_pool(rating: 1, count: 20) +
          review_pool(rating: 3, count: 400) +
          review_pool(rating: 5, count: 400)
      end

      it "includes every available negative review" do
        expect(select_for_store[:bands][:negative]).to eq(20)
      end

      it "redistributes the full negative deficit to the mixed band (first surplus band in order)" do
        negative_quota = (ReviewSelector::MAX_REVIEWS_PER_STORE * ReviewSelector::BANDS[:negative][:share]).round
        mixed_quota = (ReviewSelector::MAX_REVIEWS_PER_STORE * ReviewSelector::BANDS[:mixed][:share]).round
        deficit = negative_quota - 20

        expect(select_for_store[:bands][:mixed]).to eq(mixed_quota + deficit)
      end

      it "leaves the positive band at its own quota, unaffected by the spillover" do
        positive_quota = (ReviewSelector::MAX_REVIEWS_PER_STORE * ReviewSelector::BANDS[:positive][:share]).round
        expect(select_for_store[:bands][:positive]).to eq(positive_quota)
      end

      it "the store total still reaches the sum of quotas since ample surplus was available" do
        total_quota = ReviewSelector::BANDS.each_key.sum do |band|
          (ReviewSelector::MAX_REVIEWS_PER_STORE * ReviewSelector::BANDS[band][:share]).round
        end
        expect(select_for_store[:selected].size).to eq(total_quota)
      end
    end

    context "when an app's reviews all fall in a single band" do
      let(:pool) { review_pool(rating: 5, count: 800) }

      it "selects only from the positive band" do
        bands = select_for_store[:bands]
        expect(bands.values_at(:negative, :mixed)).to eq([ 0, 0 ])
        expect(bands[:positive]).to be > 0
      end

      it "does not exceed the per-store cap plus the accepted rounding artifact from summed quotas" do
        expect(select_for_store[:selected].size).to be <= ReviewSelector::MAX_REVIEWS_PER_STORE + 1
      end

      it "still produces a non-empty, valid selection" do
        expect(select_for_store[:selected]).not_to be_empty
      end
    end

    context "unrated reviews" do
      it "are never counted in a rated band" do
        pool = review_pool(rating: nil, count: 50)

        result = described_class.new(nil).send(:select_for_store, pool)

        expect(result[:bands].values_at(:negative, :mixed, :positive)).to eq([ 0, 0, 0 ])
      end

      it "fill leftover per-store headroom after rated bands are exhausted" do
        pool = review_pool(rating: 1, count: 50) + review_pool(rating: nil, count: 600)

        result = described_class.new(nil).send(:select_for_store, pool)

        expect(result[:bands][:unrated]).to eq(ReviewSelector::MAX_REVIEWS_PER_STORE - 50)
      end

      it "produces a full valid selection when every review is unrated" do
        pool = review_pool(rating: nil, count: 50)

        result = described_class.new(nil).send(:select_for_store, pool)

        expect(result[:selected].size).to eq(50)
        expect(result[:bands][:unrated]).to eq(50)
      end
    end
  end

  describe ".select — cross-store spillover (BRA-82 regression, on top of band stratification)" do
    context "when an app has reviews in only one store" do
      let!(:app_store_reviews) do
        1200.times.map { |i| create(:review, app: app, store: :app_store, external_id: "s#{i}", rating: (i % 5) + 1, body: substantive_body("single#{i}"), reviewed_at: (i + 1).minutes.ago) }
      end

      it "still selects the full MAX_REVIEWS_TOTAL from the single store" do
        result = described_class.select(Review.where(app: app))

        expect(result.app_store.size).to eq(ReviewSelector::MAX_REVIEWS_TOTAL)
        expect(result.play_store).to be_empty
      end
    end

    context "when one store has far more reviews than the other (lopsided)" do
      let!(:app_store_reviews) do
        960.times.map { |i| create(:review, app: app, store: :app_store, external_id: "a#{i}", rating: (i % 5) + 1, body: substantive_body("app#{i}"), reviewed_at: (i + 1).minutes.ago) }
      end

      let!(:play_store_reviews) do
        40.times.map { |i| create(:review, app: app, store: :play_store, external_id: "p#{i}", rating: (i % 5) + 1, body: substantive_body("play#{i}"), reviewed_at: (i + 1).minutes.ago) }
      end

      it "includes every play_store review" do
        result = described_class.select(Review.where(app: app))

        expect(result.play_store.size).to eq(40)
      end

      it "fills the rest of the 1000 total with app_store reviews via spillover" do
        result = described_class.select(Review.where(app: app))

        expect(result.app_store.size).to eq(960)
      end
    end

    context "metadata consistency — spilled-in reviews are attributed to a band or unrated, not dropped from the count" do
      let!(:app_store_reviews) do
        960.times.map { |i| create(:review, app: app, store: :app_store, external_id: "a#{i}", rating: (i % 5) + 1, body: substantive_body("app#{i}"), reviewed_at: (i + 1).minutes.ago) }
      end

      let!(:play_store_reviews) do
        40.times.map { |i| create(:review, app: app, store: :play_store, external_id: "p#{i}", rating: (i % 5) + 1, body: substantive_body("play#{i}"), reviewed_at: (i + 1).minutes.ago) }
      end

      it "sums app_store band counts to exactly the number of app_store reviews selected" do
        result = described_class.select(Review.where(app: app))

        expect(result.metadata[:selected][:app_store].values.sum).to eq(result.app_store.size)
      end

      it "sums play_store band counts to exactly the number of play_store reviews selected" do
        result = described_class.select(Review.where(app: app))

        expect(result.metadata[:selected][:play_store].values.sum).to eq(result.play_store.size)
      end
    end
  end

  describe ".select — edge cases produce a valid Result" do
    it "an app whose reviews all fall in one band still selects successfully" do
      100.times { |i| create(:review, app: app, store: :app_store, external_id: "p#{i}", rating: 5, body: substantive_body("onlypositive#{i}"), reviewed_at: (i + 1).minutes.ago) }

      result = described_class.select(Review.where(app: app))

      expect(result.app_store).not_to be_empty
      expect(result.metadata[:selected][:app_store].values_at(:negative, :mixed)).to eq([ 0, 0 ])
    end

    it "an app with only unrated reviews still produces a valid selection" do
      30.times { |i| create(:review, app: app, store: :app_store, external_id: "u#{i}", rating: nil, body: substantive_body("unrated#{i}"), reviewed_at: (i + 1).minutes.ago) }

      result = described_class.select(Review.where(app: app))

      expect(result.app_store.size).to eq(30)
      expect(result.metadata[:selected][:app_store][:unrated]).to eq(30)
      expect(result.metadata[:distribution]["unrated"]).to eq(30)
    end
  end

  describe "Result" do
    it "responds to app_store, play_store, and metadata" do
      result = described_class.select(Review.where(app: app))

      expect(result).to respond_to(:app_store, :play_store, :metadata)
    end
  end
end
