# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Reports", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user)      { create(:user) }
  let(:workspace) { create(:workspace) }

  # Ensure the user is a member of the workspace
  def make_member(u = user, role: :admin)
    create(:workspace_membership, user: u, workspace: workspace, role: role)
  end

  # ---------------------------------------------------------------------------
  # GET /workspaces/:workspace_id/apps/:app_id/reports/:id
  # ---------------------------------------------------------------------------
  describe "GET /workspaces/:workspace_id/apps/:app_id/reports/:id" do
    let(:the_app) { create(:app, workspace: workspace) }
    let(:report)  { create(:report, app: the_app) }

    context "when signed in as a collaborator" do
      before do
        make_member(role: :collaborator)
        sign_in user
      end

      it "returns 200 OK" do
        get workspace_app_report_path(workspace, the_app, report)
        expect(response).to have_http_status(:ok)
      end
    end

    context "when signed in as an admin" do
      before do
        make_member(role: :admin)
        sign_in user
      end

      it "returns 200 OK" do
        get workspace_app_report_path(workspace, the_app, report)
        expect(response).to have_http_status(:ok)
      end
    end

    context "when signed in as a super_admin" do
      before do
        make_member(role: :super_admin)
        sign_in user
      end

      it "returns 200 OK" do
        get workspace_app_report_path(workspace, the_app, report)
        expect(response).to have_http_status(:ok)
      end
    end

    context "when the user is not a workspace member" do
      let(:other_workspace) { create(:workspace) }
      let(:other_app)       { create(:app, workspace: other_workspace) }
      let(:other_report)    { create(:report, app: other_app) }

      before { sign_in user }

      it "returns 404" do
        get workspace_app_report_path(other_workspace, other_app, other_report)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when not signed in" do
      it "redirects to sign in" do
        get workspace_app_report_path(workspace, the_app, report)
        expect(response).to redirect_to(sign_in_path)
      end
    end
  end
end
