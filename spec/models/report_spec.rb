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

    it "defines all report_type values" do
      expect(described_class.report_types).to eq(
        "generate" => 0,
        "refresh" => 1,
        "reanalyze" => 2
      )
    end

    it "defaults report_type to generate for a new record" do
      report = build(:report)
      expect(report.report_type).to eq("generate")
    end

    it "defaults report_type to generate for a persisted record with no report_type given" do
      report = create(:report)
      expect(report.reload.report_type).to eq("generate")
    end

    it "accepts refresh as a report_type" do
      report = build(:report, report_type: :refresh)
      expect(report.report_type).to eq("refresh")
    end

    it "accepts reanalyze as a report_type" do
      report = build(:report, report_type: :reanalyze)
      expect(report.report_type).to eq("reanalyze")
    end
  end

  describe "validations" do
    it "is valid with required attributes" do
      report = build(:report)
      expect(report).to be_valid
    end
  end
end
