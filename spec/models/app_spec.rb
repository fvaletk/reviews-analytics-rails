# frozen_string_literal: true

require "rails_helper"

RSpec.describe App, type: :model do
  describe "associations" do
    it "belongs to workspace" do
      association = described_class.reflect_on_association(:workspace)
      expect(association.macro).to eq(:belongs_to)
    end

    it "belongs to created_by as User" do
      association = described_class.reflect_on_association(:created_by)
      expect(association.macro).to eq(:belongs_to)
      expect(association.options[:class_name]).to eq("User")
    end

    it "has many reviews" do
      association = described_class.reflect_on_association(:reviews)
      expect(association.macro).to eq(:has_many)
    end

    it "destroys reviews when app is destroyed" do
      association = described_class.reflect_on_association(:reviews)
      expect(association.options[:dependent]).to eq(:destroy)
    end

    it "has many reports" do
      association = described_class.reflect_on_association(:reports)
      expect(association.macro).to eq(:has_many)
    end

    it "destroys reports when app is destroyed" do
      association = described_class.reflect_on_association(:reports)
      expect(association.options[:dependent]).to eq(:destroy)
    end
  end

  describe "Workspace#apps association" do
    it "workspace has_many apps" do
      association = Workspace.reflect_on_association(:apps)
      expect(association.macro).to eq(:has_many)
    end

    it "destroys apps when workspace is destroyed" do
      association = Workspace.reflect_on_association(:apps)
      expect(association.options[:dependent]).to eq(:destroy)
    end

    it "workspace lists its apps" do
      workspace = create(:workspace)
      app = create(:app, workspace: workspace)
      expect(workspace.apps).to include(app)
    end
  end

  describe "validations" do
    context "with only app_store_id" do
      it "is valid" do
        app = build(:app, app_store_id: "123456789", play_store_id: nil)
        expect(app).to be_valid
      end
    end

    context "with only play_store_id" do
      it "is valid" do
        app = build(:app, app_store_id: nil, play_store_id: "com.example.app")
        expect(app).to be_valid
      end
    end

    context "with both store IDs" do
      it "is valid" do
        app = build(:app, app_store_id: "123456789", play_store_id: "com.example.app")
        expect(app).to be_valid
      end
    end

    context "with neither store ID" do
      it "is invalid" do
        app = build(:app, app_store_id: nil, play_store_id: nil)
        expect(app).not_to be_valid
      end

      it "adds an error on base" do
        app = build(:app, app_store_id: nil, play_store_id: nil)
        app.valid?
        expect(app.errors[:base]).to include("must have at least one of app_store_id or play_store_id")
      end
    end

    context "name validation" do
      it "is invalid without a name" do
        app = build(:app, name: nil)
        expect(app).not_to be_valid
      end

      it "is invalid with a blank name" do
        app = build(:app, name: "")
        expect(app).not_to be_valid
      end
    end
  end

  describe "ICP defaults" do
    subject(:app) { create(:app) }

    it "has a nil icp, not an empty hash" do
      expect(app.icp).to be_nil
    end

    it "defaults icp_usage_metadata to an empty hash" do
      expect(app.icp_usage_metadata).to eq({})
    end

    it "is not extraction attempted" do
      expect(app.icp_extraction_attempted?).to be false
    end

    it "is not extracted" do
      expect(app.icp_extracted?).to be false
    end
  end

  describe "icp_usage_metadata not null constraint" do
    it "raises when set to nil at the database level" do
      app = create(:app)
      expect { app.update_column(:icp_usage_metadata, nil) }
        .to raise_error(ActiveRecord::NotNullViolation)
    end
  end

  describe "#icp_extraction_attempted?" do
    context "when icp has never been run" do
      let(:app) { build(:app, icp: nil, icp_generated_at: nil) }

      it "returns false" do
        expect(app.icp_extraction_attempted?).to be false
      end
    end

    context "when icp extraction was declined" do
      let(:app) { build(:app, :icp_declined) }

      it "returns true" do
        expect(app.icp_extraction_attempted?).to be true
      end
    end

    context "when icp was extracted" do
      let(:app) { build(:app, :with_icp) }

      it "returns true" do
        expect(app.icp_extraction_attempted?).to be true
      end
    end
  end

  describe "#icp_extracted?" do
    context "when icp has never been run" do
      let(:app) { build(:app, icp: nil, icp_generated_at: nil) }

      it "returns false" do
        expect(app.icp_extracted?).to be false
      end
    end

    context "when icp extraction was declined" do
      let(:app) { build(:app, :icp_declined) }

      it "returns false" do
        expect(app.icp_extracted?).to be false
      end
    end

    context "when icp was extracted" do
      let(:app) { build(:app, :with_icp) }

      it "returns true" do
        expect(app.icp_extracted?).to be true
      end
    end
  end
end
