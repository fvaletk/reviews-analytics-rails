# frozen_string_literal: true

require "rails_helper"

RSpec.describe Report, type: :model do
  describe "associations" do
    it "belongs to app" do
      association = described_class.reflect_on_association(:app)
      expect(association.macro).to eq(:belongs_to)
    end

    it "belongs to generated_by as User" do
      association = described_class.reflect_on_association(:generated_by)
      expect(association.macro).to eq(:belongs_to)
      expect(association.options[:class_name]).to eq("User")
    end
  end

  describe "enums" do
    it "defines all status values" do
      expect(described_class.statuses).to eq(
        "pending" => 0,
        "fetching" => 1,
        "analyzing" => 2,
        "complete" => 3,
        "failed" => 4
      )
    end
  end

  describe "validations" do
    it "is valid with required attributes" do
      report = build(:report)
      expect(report).to be_valid
    end
  end
end
