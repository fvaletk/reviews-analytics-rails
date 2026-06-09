# frozen_string_literal: true

require "rails_helper"

RSpec.describe PendingInvitation, type: :model do
  describe "validations" do
    let(:workspace) { create(:workspace) }
    let(:inviter)   { create(:user) }

    it "is valid with valid attributes" do
      invitation = build(:pending_invitation, workspace: workspace, invited_by_user: inviter)
      expect(invitation).to be_valid
    end

    it "is invalid without an email" do
      invitation = build(:pending_invitation, workspace: workspace, email: nil)
      expect(invitation).not_to be_valid
    end

    it "is invalid without a role" do
      invitation = build(:pending_invitation, workspace: workspace, role: nil)
      expect(invitation).not_to be_valid
    end

    it "is invalid when the same email is invited to the same workspace twice" do
      create(:pending_invitation, workspace: workspace, email: "dup@example.com")
      duplicate = build(:pending_invitation, workspace: workspace, email: "dup@example.com")
      expect(duplicate).not_to be_valid
    end

    it "allows the same email to be invited to different workspaces" do
      other_workspace = create(:workspace)
      create(:pending_invitation, workspace: workspace, email: "multi@example.com")
      different = build(:pending_invitation, workspace: other_workspace, email: "multi@example.com")
      expect(different).to be_valid
    end
  end

  describe "role enum" do
    it "recognises collaborator" do
      invitation = build(:pending_invitation, role: :collaborator)
      expect(invitation.collaborator?).to be true
    end

    it "recognises admin" do
      invitation = build(:pending_invitation, role: :admin)
      expect(invitation.admin?).to be true
    end

    it "recognises super_admin" do
      invitation = build(:pending_invitation, role: :super_admin)
      expect(invitation.super_admin?).to be true
    end
  end

  describe "associations" do
    it "belongs to workspace" do
      association = described_class.reflect_on_association(:workspace)
      expect(association.macro).to eq(:belongs_to)
    end

    it "belongs to invited_by_user (optional)" do
      association = described_class.reflect_on_association(:invited_by_user)
      expect(association.macro).to eq(:belongs_to)
      expect(association.options[:optional]).to be true
    end
  end
end
