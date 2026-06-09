# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Workspaces", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user) }

  describe "GET /workspaces/new" do
    context "when signed in" do
      before { sign_in user }

      it "returns 200 OK" do
        get new_workspace_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "when not signed in" do
      it "redirects to sign in" do
        get new_workspace_path
        expect(response).to redirect_to(sign_in_path)
      end
    end
  end

  describe "POST /workspaces" do
    context "when signed in" do
      before { sign_in user }

      context "with a valid name" do
        it "creates a new workspace" do
          expect {
            post workspaces_path, params: { workspace: { name: "Acme Corp" } }
          }.to change(Workspace, :count).by(1)
        end

        it "assigns the creator as super_admin" do
          post workspaces_path, params: { workspace: { name: "Acme Corp" } }
          workspace = Workspace.last
          membership = WorkspaceMembership.find_by(user: user, workspace: workspace)
          expect(membership.role).to eq("super_admin")
        end

        it "creates a membership in the same transaction" do
          expect {
            post workspaces_path, params: { workspace: { name: "Acme Corp" } }
          }.to change(WorkspaceMembership, :count).by(1)
        end

        it "redirects to the new workspace" do
          post workspaces_path, params: { workspace: { name: "Acme Corp" } }
          expect(response).to redirect_to(workspace_path(Workspace.last))
        end

        context "when a workspace with the same name already exists" do
          before { create(:workspace, name: "My App", slug: "my-app") }

          it "generates a unique slug for the second workspace" do
            post workspaces_path, params: { workspace: { name: "My App" } }
            expect(Workspace.last.slug).to eq("my-app-2")
          end

          it "still creates the second workspace successfully" do
            expect {
              post workspaces_path, params: { workspace: { name: "My App" } }
            }.to change(Workspace, :count).by(1)
          end
        end
      end

      context "with a missing name" do
        it "does not create a workspace" do
          expect {
            post workspaces_path, params: { workspace: { name: "" } }
          }.not_to change(Workspace, :count)
        end

        it "returns 422 Unprocessable Entity" do
          post workspaces_path, params: { workspace: { name: "" } }
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "re-renders the new form" do
          post workspaces_path, params: { workspace: { name: "" } }
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    context "when not signed in" do
      it "redirects to sign in" do
        post workspaces_path, params: { workspace: { name: "Acme Corp" } }
        expect(response).to redirect_to(sign_in_path)
      end

      it "does not create a workspace" do
        expect {
          post workspaces_path, params: { workspace: { name: "Acme Corp" } }
        }.not_to change(Workspace, :count)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /workspaces/:id
  # ---------------------------------------------------------------------------
  describe "GET /workspaces/:id" do
    let(:workspace) { create(:workspace) }

    # Helper — create a user with the given role in workspace
    def member_with_role(role)
      u = create(:user)
      create(:workspace_membership, user: u, workspace: workspace, role: role)
      u
    end

    context "when signed in as collaborator" do
      before { sign_in member_with_role(:collaborator) }

      it "returns 200 OK" do
        get workspace_path(workspace)
        expect(response).to have_http_status(:ok)
      end
    end

    context "when signed in as admin" do
      before { sign_in member_with_role(:admin) }

      it "returns 200 OK" do
        get workspace_path(workspace)
        expect(response).to have_http_status(:ok)
      end
    end

    context "when signed in as super_admin" do
      before do
        sign_in member_with_role(:super_admin)
        # Add a second member so the REMOVE button appears in at least one row
        create(:workspace_membership, workspace: workspace, role: :collaborator)
      end

      it "returns 200 OK" do
        get workspace_path(workspace)
        expect(response).to have_http_status(:ok)
      end

      it "includes the INVITE MEMBER link in the response body" do
        get workspace_path(workspace)
        expect(response.body).to include("INVITE MEMBER")
      end

      it "includes the REMOVE button in the response body" do
        get workspace_path(workspace)
        expect(response.body).to include("REMOVE")
      end
    end

    context "when signed in as collaborator (non-admin)" do
      before { sign_in member_with_role(:collaborator) }

      it "does not include the INVITE MEMBER link in the response body" do
        get workspace_path(workspace)
        expect(response.body).not_to include("INVITE MEMBER")
      end

      it "does not include the REMOVE button in the response body" do
        get workspace_path(workspace)
        expect(response.body).not_to include("REMOVE")
      end
    end

    context "when signed in as admin (non-super_admin)" do
      before { sign_in member_with_role(:admin) }

      it "does not include the INVITE MEMBER link in the response body" do
        get workspace_path(workspace)
        expect(response.body).not_to include("INVITE MEMBER")
      end

      it "does not include the REMOVE button in the response body" do
        get workspace_path(workspace)
        expect(response.body).not_to include("REMOVE")
      end
    end

    context "when signed in as a non-member (authenticated but no membership)" do
      before { sign_in create(:user) }

      it "returns 404 (Pundit NotAuthorizedError)" do
        get workspace_path(workspace)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when not signed in" do
      it "redirects to sign in" do
        get workspace_path(workspace)
        expect(response).to redirect_to(sign_in_path)
      end
    end
  end
end
