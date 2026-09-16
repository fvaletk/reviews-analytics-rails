# frozen_string_literal: true

require "rails_helper"

RSpec.describe AppsHelper, type: :helper do
  describe "#icp_signal_groups" do
    it "groups signals by their role_hint" do
      app = build(:app, :with_icp, icp: {
        "primary_segment" => "busy freelancers",
        "confidence" => "high",
        "signals" => [
          { "quote" => "quote 1", "role_hint" => "freelancer" },
          { "quote" => "quote 2", "role_hint" => "freelancer" },
          { "quote" => "quote 3", "role_hint" => "consultant" }
        ]
      })

      groups = helper.icp_signal_groups(app)

      expect(groups.to_h.keys).to contain_exactly("freelancer", "consultant")
    end

    it "orders groups by size descending" do
      app = build(:app, :with_icp, icp: {
        "primary_segment" => "busy freelancers",
        "confidence" => "high",
        "signals" => [
          { "quote" => "quote 1", "role_hint" => "consultant" },
          { "quote" => "quote 2", "role_hint" => "freelancer" },
          { "quote" => "quote 3", "role_hint" => "freelancer" }
        ]
      })

      groups = helper.icp_signal_groups(app)

      expect(groups.map(&:first)).to eq(%w[freelancer consultant])
    end

    it "keeps two role_hints differing only in case as separate groups" do
      app = build(:app, :with_icp, icp: {
        "primary_segment" => "busy freelancers",
        "confidence" => "high",
        "signals" => [
          { "quote" => "quote 1", "role_hint" => "property manager" },
          { "quote" => "quote 2", "role_hint" => "Property Manager" }
        ]
      })

      groups = helper.icp_signal_groups(app)

      expect(groups.to_h.keys).to contain_exactly("property manager", "Property Manager")
    end

    it "returns [] when icp is nil" do
      app = build(:app, icp: nil)

      expect(helper.icp_signal_groups(app)).to eq([])
    end

    it "returns [] when icp has no signals key" do
      app = build(:app, :with_icp, icp: { "primary_segment" => "busy freelancers", "confidence" => "high" })

      expect(helper.icp_signal_groups(app)).to eq([])
    end

    it "returns [] when the signals array is empty" do
      app = build(:app, :with_icp, icp: {
        "primary_segment" => "busy freelancers",
        "confidence" => "high",
        "signals" => []
      })

      expect(helper.icp_signal_groups(app)).to eq([])
    end

    it "returns a single group when all signals share one role_hint" do
      app = build(:app, :with_icp, icp: {
        "primary_segment" => "busy freelancers",
        "confidence" => "high",
        "signals" => [
          { "quote" => "quote 1", "role_hint" => "freelancer" },
          { "quote" => "quote 2", "role_hint" => "freelancer" }
        ]
      })

      groups = helper.icp_signal_groups(app)

      expect(groups.size).to eq(1)
    end
  end
end
