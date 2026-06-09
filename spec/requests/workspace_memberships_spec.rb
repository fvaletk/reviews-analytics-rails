# frozen_string_literal: true

require "rails_helper"

RSpec.describe "WorkspaceMemberships", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:workspace) { create(:workspace) }

  # Helper — create a user with a given membership role in `workspace`
  def user_with_role(role)
    u = create(:user)
    create(:workspace_membership, user: u, workspace: workspace, role: role)
    u
  end

  # -------------------------------------------------------------------------
  # GET /workspaces/:workspace_id/memberships/new
  # -------------------------------------------------------------------------
  describe "GET /workspaces/:workspace_id/memberships/new" do
    context "when signed in as super_admin" do
      before { sign_in user_with_role(:super_admin) }

      it "returns 200 OK" do
        get new_workspace_membership_path(workspace)
        expect(response).to have_http_status(:ok)
      end
    end

    context "when signed in as admin" do
      before { sign_in user_with_role(:admin) }

      it "returns 404 (Pundit NotAuthorizedError)" do
        get new_workspace_membership_path(workspace)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when signed in as collaborator" do
      before { sign_in user_with_role(:collaborator) }

      it "returns 404 (Pundit NotAuthorizedError)" do
        get new_workspace_membership_path(workspace)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when not signed in" do
      it "redirects to sign in" do
        get new_workspace_membership_path(workspace)
        expect(response).to redirect_to(sign_in_path)
      end
    end
  end

  # -------------------------------------------------------------------------
  # POST /workspaces/:workspace_id/memberships — existing user
  # -------------------------------------------------------------------------
  describe "POST /workspaces/:workspace_id/memberships — existing user" do
    let(:super_admin) { user_with_role(:super_admin) }
    let(:invitee)     { create(:user) }

    before { sign_in super_admin }

    it "creates a WorkspaceMembership for the existing user" do
      expect {
        post workspace_memberships_path(workspace),
             params: { workspace_membership: { email: invitee.email, role: "collaborator" } }
      }.to change(WorkspaceMembership, :count).by(1)
    end

    it "sets joined_at on the new membership" do
      post workspace_memberships_path(workspace),
           params: { workspace_membership: { email: invitee.email, role: "collaborator" } }
      membership = WorkspaceMembership.find_by(user: invitee, workspace: workspace)
      expect(membership.joined_at).not_to be_nil
    end

    it "does not create a PendingInvitation" do
      expect {
        post workspace_memberships_path(workspace),
             params: { workspace_membership: { email: invitee.email, role: "collaborator" } }
      }.not_to change(PendingInvitation, :count)
    end

    it "redirects back to the new membership form with a success notice" do
      post workspace_memberships_path(workspace),
           params: { workspace_membership: { email: invitee.email, role: "collaborator" } }
      expect(response).to redirect_to(new_workspace_membership_path(workspace))
    end

    it "assigns the inviter's id to invited_by_user_id" do
      post workspace_memberships_path(workspace),
           params: { workspace_membership: { email: invitee.email, role: "admin" } }
      membership = WorkspaceMembership.find_by(user: invitee, workspace: workspace)
      expect(membership.invited_by_user_id).to eq(super_admin.id)
    end
  end

  # -------------------------------------------------------------------------
  # POST /workspaces/:workspace_id/memberships — unknown email (pending)
  # -------------------------------------------------------------------------
  describe "POST /workspaces/:workspace_id/memberships — unknown email" do
    let(:super_admin)    { user_with_role(:super_admin) }
    let(:unknown_email)  { "unknown-#{SecureRandom.hex(4)}@example.com" }

    before { sign_in super_admin }

    it "creates a PendingInvitation" do
      expect {
        post workspace_memberships_path(workspace),
             params: { workspace_membership: { email: unknown_email, role: "collaborator" } }
      }.to change(PendingInvitation, :count).by(1)
    end

    it "does not create a WorkspaceMembership" do
      expect {
        post workspace_memberships_path(workspace),
             params: { workspace_membership: { email: unknown_email, role: "collaborator" } }
      }.not_to change(WorkspaceMembership, :count)
    end

    it "stores the correct email on the PendingInvitation" do
      post workspace_memberships_path(workspace),
           params: { workspace_membership: { email: unknown_email, role: "collaborator" } }
      invitation = PendingInvitation.find_by(workspace: workspace)
      expect(invitation.email).to eq(unknown_email)
    end

    it "stores the requested role on the PendingInvitation" do
      post workspace_memberships_path(workspace),
           params: { workspace_membership: { email: unknown_email, role: "admin" } }
      invitation = PendingInvitation.find_by(workspace: workspace)
      expect(invitation.role).to eq("admin")
    end

    it "redirects back to the new membership form with a success notice" do
      post workspace_memberships_path(workspace),
           params: { workspace_membership: { email: unknown_email, role: "collaborator" } }
      expect(response).to redirect_to(new_workspace_membership_path(workspace))
    end
  end

  # -------------------------------------------------------------------------
  # Authorization — admin and collaborator cannot POST
  # -------------------------------------------------------------------------
  describe "POST /workspaces/:workspace_id/memberships — unauthorized roles" do
    let(:target_email) { create(:user).email }

    context "when signed in as admin" do
      before { sign_in user_with_role(:admin) }

      it "returns 404 (Pundit NotAuthorizedError)" do
        post workspace_memberships_path(workspace),
             params: { workspace_membership: { email: target_email, role: "collaborator" } }
        expect(response).to have_http_status(:not_found)
      end

      it "does not create a WorkspaceMembership" do
        expect {
          post workspace_memberships_path(workspace),
               params: { workspace_membership: { email: target_email, role: "collaborator" } }
        }.not_to change(WorkspaceMembership, :count)
      end
    end

    context "when signed in as collaborator" do
      before { sign_in user_with_role(:collaborator) }

      it "returns 404 (Pundit NotAuthorizedError)" do
        post workspace_memberships_path(workspace),
             params: { workspace_membership: { email: target_email, role: "collaborator" } }
        expect(response).to have_http_status(:not_found)
      end

      it "does not create a WorkspaceMembership" do
        expect {
          post workspace_memberships_path(workspace),
               params: { workspace_membership: { email: target_email, role: "collaborator" } }
        }.not_to change(WorkspaceMembership, :count)
      end
    end
  end
end
