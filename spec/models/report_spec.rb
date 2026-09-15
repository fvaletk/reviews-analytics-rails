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

  describe "#enqueue_icp_extraction (BRA-89)" do
    let(:workspace) { create(:workspace) }
    let(:app) { create(:app, workspace: workspace) }
    let(:user) { create(:user) }
    let(:report) { create(:report, app: app, generated_by: user, status: :pending) }

    before { allow(IcpExtractionJob).to receive(:perform_later) }

    context "when a report first reaches complete" do
      it "enqueues IcpExtractionJob with the app_id" do
        report.update!(status: :complete)

        expect(IcpExtractionJob).to have_received(:perform_later).with(app.id)
      end

      it "enqueues exactly once" do
        report.update!(status: :complete)

        expect(IcpExtractionJob).to have_received(:perform_later).once
      end
    end

    context "when a second report reaches complete for the same app" do
      it "does not enqueue again — only the first complete report enqueues" do
        report.update!(status: :complete)
        other_report = create(:report, app: app, generated_by: user, status: :pending)
        other_report.update!(status: :complete)

        expect(IcpExtractionJob).to have_received(:perform_later).with(app.id).once
      end
    end

    context "when the status changes to a non-complete status" do
      it "does not enqueue on transition to fetching" do
        report.update!(status: :fetching)

        expect(IcpExtractionJob).not_to have_received(:perform_later)
      end

      it "does not enqueue on transition to analyzing" do
        report.update!(status: :analyzing)

        expect(IcpExtractionJob).not_to have_received(:perform_later)
      end
    end

    context "when a report transitions to failed" do
      it "does not enqueue" do
        report.update!(status: :failed)

        expect(IcpExtractionJob).not_to have_received(:perform_later)
      end

      it "does not consume the one shot — a later complete report still enqueues" do
        report.update!(status: :failed)
        other_report = create(:report, app: app, generated_by: user, status: :pending)

        other_report.update!(status: :complete)

        expect(IcpExtractionJob).to have_received(:perform_later).with(app.id)
      end
    end

    context "when the app has already attempted ICP extraction" do
      let(:app) { create(:app, :icp_declined, workspace: workspace) }

      it "does not enqueue" do
        report.update!(status: :complete)

        expect(IcpExtractionJob).not_to have_received(:perform_later)
      end
    end

    context "when an update does not change the status" do
      it "does not enqueue again on an unrelated attribute update" do
        report.update!(status: :complete)
        report.update!(total_reviews_analyzed: 42)

        expect(IcpExtractionJob).to have_received(:perform_later).once
      end
    end
  end
end
