# frozen_string_literal: true

require "rails_helper"

RSpec.describe Workspaces::InviteMemberService, type: :service do
  let(:workspace)  { create(:workspace) }
  let(:inviter)    { create(:user) }

  subject(:call) do
    described_class.call(
      workspace:  workspace,
      email:      email,
      role:       role,
      invited_by: inviter
    )
  end

  # ---------------------------------------------------------------------------
  # Existing user — real membership created
  # ---------------------------------------------------------------------------
  context "when the email belongs to an existing user" do
    let(:invitee) { create(:user) }
    let(:email)   { invitee.email }
    let(:role)    { "collaborator" }

    it "creates a WorkspaceMembership" do
      expect { call }.to change(WorkspaceMembership, :count).by(1)
    end

    it "sets joined_at on the new membership" do
      membership = call
      expect(membership.joined_at).not_to be_nil
    end

    it "sets the correct role on the membership" do
      membership = call
      expect(membership.role).to eq("collaborator")
    end

    it "records the inviter on the membership" do
      membership = call
      expect(membership.invited_by_user_id).to eq(inviter.id)
    end

    it "does not create a PendingInvitation" do
      expect { call }.not_to change(PendingInvitation, :count)
    end

    context "when the user is already a member" do
      before { create(:workspace_membership, user: invitee, workspace: workspace) }

      it "raises InviteMemberService::Error" do
        expect { call }.to raise_error(Workspaces::InviteMemberService::Error)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Unknown email — pending invitation created
  # ---------------------------------------------------------------------------
  context "when the email does not belong to any user" do
    let(:email) { "brand-new-#{SecureRandom.hex(4)}@example.com" }
    let(:role)  { "admin" }

    it "creates a PendingInvitation" do
      expect { call }.to change(PendingInvitation, :count).by(1)
    end

    it "does not create a WorkspaceMembership" do
      expect { call }.not_to change(WorkspaceMembership, :count)
    end

    it "stores the email on the PendingInvitation" do
      invitation = call
      expect(invitation.email).to eq(email)
    end

    it "stores the requested role on the PendingInvitation" do
      invitation = call
      expect(invitation.role).to eq("admin")
    end

    it "records the inviter on the PendingInvitation" do
      invitation = call
      expect(invitation.invited_by_user_id).to eq(inviter.id)
    end

    context "when the same email has already been invited to the same workspace" do
      before { create(:pending_invitation, workspace: workspace, email: email) }

      it "raises InviteMemberService::Error" do
        expect { call }.to raise_error(Workspaces::InviteMemberService::Error)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Invalid role
  # ---------------------------------------------------------------------------
  context "when the role is super_admin (not invitable)" do
    let(:email) { create(:user).email }
    let(:role)  { "super_admin" }

    it "raises InviteMemberService::Error" do
      expect { call }.to raise_error(Workspaces::InviteMemberService::Error, /collaborator or admin/)
    end
  end
end
