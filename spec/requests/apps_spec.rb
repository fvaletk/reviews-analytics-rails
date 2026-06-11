# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Apps", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user)      { create(:user) }
  let(:workspace) { create(:workspace) }

  # Ensure the user is a member of the workspace
  def make_member(u = user, role: :admin)
    create(:workspace_membership, user: u, workspace: workspace, role: role)
  end

  # ---------------------------------------------------------------------------
  # GET /workspaces/:workspace_id/apps/new
  # ---------------------------------------------------------------------------
  describe "GET /workspaces/:workspace_id/apps/new" do
    context "when signed in as a workspace member" do
      before do
        make_member
        sign_in user
      end

      it "returns 200 OK" do
        get new_workspace_app_path(workspace)
        expect(response).to have_http_status(:ok)
      end
    end

    context "when not signed in" do
      it "redirects to sign in" do
        get new_workspace_app_path(workspace)
        expect(response).to redirect_to(sign_in_path)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /workspaces/:workspace_id/apps
  # ---------------------------------------------------------------------------
  describe "POST /workspaces/:workspace_id/apps" do
    before do
      make_member
      sign_in user
    end

    context "with a valid App Store URL only" do
      let(:app_store_url) { "https://apps.apple.com/us/app/my-great-app/id123456789" }

      it "creates the app" do
        expect {
          post workspace_apps_path(workspace), params: {
            app: { name: "My App", app_store_url: app_store_url }
          }
        }.to change(App, :count).by(1)
      end

      it "redirects to the app show page" do
        post workspace_apps_path(workspace), params: {
          app: { name: "My App", app_store_url: app_store_url }
        }
        expect(response).to redirect_to(workspace_app_path(workspace, App.last))
      end

      it "stores the parsed app_store_id" do
        post workspace_apps_path(workspace), params: {
          app: { name: "My App", app_store_url: app_store_url }
        }
        expect(App.last.app_store_id).to eq("123456789")
      end
    end

    context "with a valid Play Store URL only" do
      let(:play_store_url) { "https://play.google.com/store/apps/details?id=com.example.myapp" }

      it "creates the app" do
        expect {
          post workspace_apps_path(workspace), params: {
            app: { name: "My App", play_store_url: play_store_url }
          }
        }.to change(App, :count).by(1)
      end

      it "redirects to the app show page" do
        post workspace_apps_path(workspace), params: {
          app: { name: "My App", play_store_url: play_store_url }
        }
        expect(response).to redirect_to(workspace_app_path(workspace, App.last))
      end

      it "stores the parsed play_store_id" do
        post workspace_apps_path(workspace), params: {
          app: { name: "My App", play_store_url: play_store_url }
        }
        expect(App.last.play_store_id).to eq("com.example.myapp")
      end
    end

    context "with both valid App Store and Play Store URLs" do
      let(:app_store_url)  { "https://apps.apple.com/gb/app/some-app/id987654321" }
      let(:play_store_url) { "https://play.google.com/store/apps/details?id=com.example.otherapp" }

      it "creates the app" do
        expect {
          post workspace_apps_path(workspace), params: {
            app: { name: "Both Stores App", app_store_url: app_store_url, play_store_url: play_store_url }
          }
        }.to change(App, :count).by(1)
      end

      it "redirects to the app show page" do
        post workspace_apps_path(workspace), params: {
          app: { name: "Both Stores App", app_store_url: app_store_url, play_store_url: play_store_url }
        }
        expect(response).to redirect_to(workspace_app_path(workspace, App.last))
      end

      it "stores both the app_store_id and play_store_id" do
        post workspace_apps_path(workspace), params: {
          app: { name: "Both Stores App", app_store_url: app_store_url, play_store_url: play_store_url }
        }
        app = App.last
        expect(app.app_store_id).to eq("987654321")
        expect(app.play_store_id).to eq("com.example.otherapp")
      end
    end

    context "with an unparseable App Store URL" do
      let(:bad_app_store_url) { "https://not-a-real-apple-url.com/app/thing" }

      it "does not create the app" do
        expect {
          post workspace_apps_path(workspace), params: {
            app: { name: "Bad URL App", app_store_url: bad_app_store_url }
          }
        }.not_to change(App, :count)
      end

      it "returns 422 Unprocessable Entity" do
        post workspace_apps_path(workspace), params: {
          app: { name: "Bad URL App", app_store_url: bad_app_store_url }
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "re-renders the new form" do
        post workspace_apps_path(workspace), params: {
          app: { name: "Bad URL App", app_store_url: bad_app_store_url }
        }
        expect(response.body).to include("form")
      end
    end

    context "with an unparseable Play Store URL" do
      let(:bad_play_store_url) { "https://play.google.com/store/apps/details" }

      it "does not create the app" do
        expect {
          post workspace_apps_path(workspace), params: {
            app: { name: "Bad Play URL App", play_store_url: bad_play_store_url }
          }
        }.not_to change(App, :count)
      end

      it "returns 422 Unprocessable Entity" do
        post workspace_apps_path(workspace), params: {
          app: { name: "Bad Play URL App", play_store_url: bad_play_store_url }
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "with no store URLs provided" do
      it "does not create the app" do
        expect {
          post workspace_apps_path(workspace), params: {
            app: { name: "No URLs App" }
          }
        }.not_to change(App, :count)
      end

      it "returns 422 Unprocessable Entity" do
        post workspace_apps_path(workspace), params: {
          app: { name: "No URLs App" }
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when the user is not a workspace member" do
      let(:other_workspace) { create(:workspace) }

      it "returns 404" do
        post workspace_apps_path(other_workspace), params: {
          app: { name: "Sneaky App", app_store_url: "https://apps.apple.com/us/app/x/id1" }
        }
        expect(response).to have_http_status(:not_found)
      end

      it "does not create the app" do
        expect {
          post workspace_apps_path(other_workspace), params: {
            app: { name: "Sneaky App", app_store_url: "https://apps.apple.com/us/app/x/id1" }
          }
        }.not_to change(App, :count)
      end
    end

    context "when not signed in" do
      before { sign_out user }

      it "redirects to sign in" do
        post workspace_apps_path(workspace), params: {
          app: { name: "Unauthenticated App", app_store_url: "https://apps.apple.com/us/app/x/id1" }
        }
        expect(response).to redirect_to(sign_in_path)
      end

      it "does not create the app" do
        expect {
          post workspace_apps_path(workspace), params: {
            app: { name: "Unauthenticated App", app_store_url: "https://apps.apple.com/us/app/x/id1" }
          }
        }.not_to change(App, :count)
      end
    end
  end
end
