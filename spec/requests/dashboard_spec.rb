# frozen_string_literal: true

require "rails_helper"
require "cgi"

RSpec.describe "Dashboard", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user) }

  describe "GET / (dashboard)" do
    context "when signed in" do
      before { sign_in user }

      it "returns 200 OK" do
        get root_path
        expect(response).to have_http_status(:ok)
      end

      it "displays the user's name" do
        get root_path
        expect(response.body).to include(CGI.escapeHTML(user.name))
      end

      it "displays the user's email" do
        get root_path
        expect(response.body).to include(user.email)
      end

      it "includes a sign out link" do
        get root_path
        expect(response.body).to include("Sign out")
      end

      it "always shows the Create workspace link" do
        get root_path
        expect(response.body).to include(new_workspace_path)
      end

      context "when the user has no workspaces" do
        it "shows the empty state message" do
          get root_path
          expect(response.body).to include("You don't have any workspaces yet")
        end

        it "shows the create first workspace CTA" do
          get root_path
          expect(response.body).to include("CREATE YOUR FIRST WORKSPACE")
        end

        it "does not show a workspace list" do
          get root_path
          expect(response.body).not_to include("Your Workspaces")
        end
      end

      context "when the user belongs to one or more workspaces" do
        let!(:workspace) { create(:workspace) }
        let!(:membership) do
          create(:workspace_membership, user: user, workspace: workspace, role: :admin)
        end

        it "shows the workspace list heading" do
          get root_path
          expect(response.body).to include("Your Workspaces")
        end

        it "shows the workspace name" do
          get root_path
          expect(response.body).to include(CGI.escapeHTML(workspace.name))
        end

        it "links to the workspace show page" do
          get root_path
          expect(response.body).to include(workspace_path(workspace))
        end

        it "shows the user's role badge" do
          get root_path
          expect(response.body).to include("admin")
        end

        it "shows the member count" do
          get root_path
          expect(response.body).to include("1 member")
        end

        it "does not show the empty state message" do
          get root_path
          expect(response.body).not_to include("You don't have any workspaces yet")
        end

        it "does not show workspaces the user is not a member of" do
          other_workspace = create(:workspace)
          get root_path
          expect(response.body).not_to include(other_workspace.name)
        end
      end
    end

    context "when not signed in" do
      it "redirects to sign_in path" do
        get root_path
        expect(response).to redirect_to(sign_in_path)
      end
    end
  end
end
