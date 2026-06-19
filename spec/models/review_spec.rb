# frozen_string_literal: true

require "rails_helper"

RSpec.describe Review, type: :model do
  describe "associations" do
    it "belongs to app" do
      association = described_class.reflect_on_association(:app)
      expect(association.macro).to eq(:belongs_to)
    end
  end

  describe "enums" do
    it "defines store enum with app_store and play_store" do
      expect(described_class.stores).to eq("app_store" => 0, "play_store" => 1)
    end
  end

  describe "validations" do
    it "is valid with required attributes" do
      review = build(:review)
      expect(review).to be_valid
    end

    it "is invalid without external_id" do
      review = build(:review, external_id: nil)
      expect(review).not_to be_valid
    end

    it "is invalid without store" do
      review = build(:review, store: nil)
      expect(review).not_to be_valid
    end
  end

  describe "uniqueness index on (app_id, store, external_id)" do
    it "prevents duplicate (app_id, store, external_id) at the DB level" do
      review = create(:review)
      duplicate = build(:review, app: review.app, store: review.store, external_id: review.external_id)
      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows same external_id for a different store" do
      review = create(:review, store: :app_store, external_id: "abc123")
      other = build(:review, app: review.app, store: :play_store, external_id: "abc123")
      expect(other).to be_valid
    end
  end
end
