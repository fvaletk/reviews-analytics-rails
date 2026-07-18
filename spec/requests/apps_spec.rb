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
  # GET /workspaces/:workspace_id/apps/:id
  # ---------------------------------------------------------------------------
  describe "GET /workspaces/:workspace_id/apps/:id" do
    let(:the_app) { create(:app, workspace: workspace) }

    context "when signed in as a collaborator" do
      before do
        make_member(role: :collaborator)
        sign_in user
      end

      it "returns 200 OK" do
        get workspace_app_path(workspace, the_app)
        expect(response).to have_http_status(:ok)
      end
    end

    context "when signed in as an admin" do
      before do
        make_member(role: :admin)
        sign_in user
      end

      it "returns 200 OK" do
        get workspace_app_path(workspace, the_app)
        expect(response).to have_http_status(:ok)
      end
    end

    context "when signed in as a super_admin" do
      before do
        make_member(role: :super_admin)
        sign_in user
      end

      it "returns 200 OK" do
        get workspace_app_path(workspace, the_app)
        expect(response).to have_http_status(:ok)
      end
    end

    context "when the user is not a workspace member" do
      let(:other_workspace) { create(:workspace) }
      let(:other_app)       { create(:app, workspace: other_workspace) }

      before { sign_in user }

      it "returns 404" do
        get workspace_app_path(other_workspace, other_app)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when not signed in" do
      it "redirects to sign in" do
        get workspace_app_path(workspace, the_app)
        expect(response).to redirect_to(sign_in_path)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /workspaces/:workspace_id/apps/:id — action rail buttons
  # (BRA-74: Re-analyze/Refresh disabled until a report has completed)
  # ---------------------------------------------------------------------------
  describe "action rail buttons on the app show page" do
    let(:the_app) { create(:app, workspace: workspace) }

    def find_button(body, text)
      Nokogiri::HTML::Document.parse(body).css("button").find { |btn| btn.text.strip == text }
    end

    context "when the app has no completed reports" do
      before do
        make_member(role: :admin)
        sign_in user
      end

      context "and there are no reports at all" do
        it "renders 'Re-analyze existing reviews' as disabled" do
          get workspace_app_path(workspace, the_app)
          button = find_button(response.body, "Re-analyze existing reviews")
          expect(button["disabled"]).to be_present
        end

        it "renders 'Refresh reviews + re-analyze' as disabled" do
          get workspace_app_path(workspace, the_app)
          button = find_button(response.body, "Refresh reviews + re-analyze")
          expect(button["disabled"]).to be_present
        end

        it "explains why 'Re-analyze existing reviews' is disabled" do
          get workspace_app_path(workspace, the_app)
          button = find_button(response.body, "Re-analyze existing reviews")
          expect(button["title"]).to eq("Generate a report first")
        end

        it "explains why 'Refresh reviews + re-analyze' is disabled" do
          get workspace_app_path(workspace, the_app)
          button = find_button(response.body, "Refresh reviews + re-analyze")
          expect(button["title"]).to eq("Generate a report first")
        end

        it "still renders 'Generate Report' without a disabled attribute" do
          get workspace_app_path(workspace, the_app)
          button = find_button(response.body, "Generate Report")
          expect(button["disabled"]).to be_nil
        end
      end

      context "and there are only pending/failed reports" do
        before do
          create(:report, app: the_app, status: :pending)
          create(:report, app: the_app, status: :failed)
        end

        it "still renders 'Re-analyze existing reviews' as disabled" do
          get workspace_app_path(workspace, the_app)
          button = find_button(response.body, "Re-analyze existing reviews")
          expect(button["disabled"]).to be_present
        end

        it "still renders 'Refresh reviews + re-analyze' as disabled" do
          get workspace_app_path(workspace, the_app)
          button = find_button(response.body, "Refresh reviews + re-analyze")
          expect(button["disabled"]).to be_present
        end
      end
    end

    context "when the app has at least one completed report" do
      before do
        create(:report, app: the_app, status: :complete)
        make_member(role: :admin)
        sign_in user
      end

      it "renders 'Re-analyze existing reviews' without the disabled attribute" do
        get workspace_app_path(workspace, the_app)
        button = find_button(response.body, "Re-analyze existing reviews")
        expect(button["disabled"]).to be_nil
      end

      it "renders 'Refresh reviews + re-analyze' without the disabled attribute" do
        get workspace_app_path(workspace, the_app)
        button = find_button(response.body, "Refresh reviews + re-analyze")
        expect(button["disabled"]).to be_nil
      end

      it "does not render the disabled explanation title" do
        get workspace_app_path(workspace, the_app)
        button = find_button(response.body, "Re-analyze existing reviews")
        expect(button["title"]).to be_nil
      end
    end

    context "when the user is a collaborator (cannot generate reports)" do
      before do
        make_member(role: :collaborator)
        sign_in user
      end

      it "does not render the 'Generate Report' button" do
        get workspace_app_path(workspace, the_app)
        expect(find_button(response.body, "Generate Report")).to be_nil
      end

      it "does not render the secondary action buttons" do
        get workspace_app_path(workspace, the_app)
        expect(find_button(response.body, "Re-analyze existing reviews")).to be_nil
      end
    end

    context "when the user is an admin (can generate reports)" do
      before do
        make_member(role: :admin)
        sign_in user
      end

      it "renders the 'Generate Report' button regardless of report history" do
        get workspace_app_path(workspace, the_app)
        expect(find_button(response.body, "Generate Report")).to be_present
      end
    end
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
