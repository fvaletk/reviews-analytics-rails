# frozen_string_literal: true

require "rails_helper"

RSpec.describe Workspace, type: :model do
  describe "associations" do
    it "has many workspace_memberships" do
      association = described_class.reflect_on_association(:workspace_memberships)
      expect(association.macro).to eq(:has_many)
    end

    it "destroys workspace_memberships when destroyed" do
      association = described_class.reflect_on_association(:workspace_memberships)
      expect(association.options[:dependent]).to eq(:destroy)
    end

    it "has many users through workspace_memberships" do
      association = described_class.reflect_on_association(:users)
      expect(association.macro).to eq(:has_many)
      expect(association.options[:through]).to eq(:workspace_memberships)
    end
  end

  describe "validations" do
    it "is valid with a name" do
      workspace = build(:workspace)
      expect(workspace).to be_valid
    end

    it "is invalid without a name" do
      workspace = build(:workspace, name: nil)
      expect(workspace).not_to be_valid
    end

    it "is invalid with a duplicate slug" do
      create(:workspace, name: "Acme Corp")
      workspace = build(:workspace, name: "Acme Corp")
      # slug will be generated from name, so clear it to force re-generation
      workspace.slug = nil
      workspace.valid?
      # Now assign the same slug explicitly
      workspace.slug = "acme-corp"
      expect(workspace).not_to be_valid
    end

    it "is invalid without a slug" do
      workspace = build(:workspace, name: "Some Name")
      workspace.slug = nil
      # bypass the before_validation callback by preventing re-generation
      allow(workspace).to receive(:set_slug_from_name)
      expect(workspace).not_to be_valid
    end
  end

  describe "slug auto-generation" do
    it "generates a slug from the name before validation" do
      workspace = build(:workspace, name: "My Workspace")
      workspace.valid?
      expect(workspace.slug).to eq("my-workspace")
    end

    it "does not overwrite an already set slug" do
      workspace = build(:workspace, name: "My Workspace", slug: "custom-slug")
      workspace.valid?
      expect(workspace.slug).to eq("custom-slug")
    end

    it "parameterizes the name for the slug" do
      workspace = build(:workspace, name: "Hello World & Co.")
      workspace.valid?
      expect(workspace.slug).to eq("hello-world-co")
    end

    it "persists with an auto-generated slug" do
      workspace = create(:workspace, name: "Slug Test")
      expect(workspace.reload.slug).to eq("slug-test")
    end
  end

  describe "uniqueness of slug at the database level" do
    it "raises on duplicate slug" do
      create(:workspace, name: "Dup Corp")
      duplicate = build(:workspace, name: "Other Name", slug: "dup-corp")
      expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "schema" do
    subject(:columns) { described_class.column_names }

    it "has a name column" do
      expect(columns).to include("name")
    end

    it "has a slug column" do
      expect(columns).to include("slug")
    end
  end
end
