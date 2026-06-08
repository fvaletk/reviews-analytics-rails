# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorkspaceMembership, type: :model do
  describe "associations" do
    it "belongs to user" do
      association = described_class.reflect_on_association(:user)
      expect(association.macro).to eq(:belongs_to)
    end

    it "belongs to workspace" do
      association = described_class.reflect_on_association(:workspace)
      expect(association.macro).to eq(:belongs_to)
    end

    it "belongs to invited_by_user" do
      association = described_class.reflect_on_association(:invited_by_user)
      expect(association.macro).to eq(:belongs_to)
    end

    it "makes invited_by_user optional" do
      association = described_class.reflect_on_association(:invited_by_user)
      expect(association.options[:optional]).to be true
    end

    it "sets invited_by_user class_name to User" do
      association = described_class.reflect_on_association(:invited_by_user)
      expect(association.options[:class_name]).to eq("User")
    end

    it "sets invited_by_user foreign_key to invited_by_user_id" do
      association = described_class.reflect_on_association(:invited_by_user)
      expect(association.options[:foreign_key]).to eq(:invited_by_user_id)
    end
  end

  describe "enum role" do
    it "defines collaborator as 0" do
      expect(described_class.roles[:collaborator]).to eq(0)
    end

    it "defines admin as 1" do
      expect(described_class.roles[:admin]).to eq(1)
    end

    it "defines super_admin as 2" do
      expect(described_class.roles[:super_admin]).to eq(2)
    end

    it "responds to collaborator? predicate" do
      membership = build(:workspace_membership, role: :collaborator)
      expect(membership).to be_collaborator
    end

    it "responds to admin? predicate" do
      membership = build(:workspace_membership, role: :admin)
      expect(membership).to be_admin
    end

    it "responds to super_admin? predicate" do
      membership = build(:workspace_membership, role: :super_admin)
      expect(membership).to be_super_admin
    end
  end

  describe "validations" do
    it "is valid with all required attributes" do
      membership = build(:workspace_membership)
      expect(membership).to be_valid
    end

    it "is invalid without a role" do
      membership = build(:workspace_membership, role: nil)
      expect(membership).not_to be_valid
    end

    it "is invalid without a user" do
      membership = build(:workspace_membership, user: nil)
      expect(membership).not_to be_valid
    end

    it "is invalid without a workspace" do
      membership = build(:workspace_membership, workspace: nil)
      expect(membership).not_to be_valid
    end

    it "is valid without invited_by_user" do
      membership = build(:workspace_membership, invited_by_user: nil)
      expect(membership).to be_valid
    end
  end

  describe "uniqueness of (user_id, workspace_id)" do
    it "raises on duplicate (user_id, workspace_id) at the database level" do
      membership = create(:workspace_membership)
      duplicate = build(:workspace_membership,
                        user: membership.user,
                        workspace: membership.workspace,
                        role: :collaborator)
      expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "schema" do
    subject(:columns) { described_class.column_names }

    it "has a user_id column" do
      expect(columns).to include("user_id")
    end

    it "has a workspace_id column" do
      expect(columns).to include("workspace_id")
    end

    it "has a role column" do
      expect(columns).to include("role")
    end

    it "has an invited_by_user_id column" do
      expect(columns).to include("invited_by_user_id")
    end

    it "has a joined_at column" do
      expect(columns).to include("joined_at")
    end
  end
end
