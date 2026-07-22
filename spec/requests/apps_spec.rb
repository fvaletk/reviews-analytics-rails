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

      it "renders 'Generate Report' without the disabled attribute" do
        get workspace_app_path(workspace, the_app)
        button = find_button(response.body, "Generate Report")
        expect(button["disabled"]).to be_nil
      end

      it "does not render the disabled explanation title" do
        get workspace_app_path(workspace, the_app)
        button = find_button(response.body, "Re-analyze existing reviews")
        expect(button["title"]).to be_nil
      end
    end

    # -------------------------------------------------------------------------
    # BRA-75: all three buttons disabled while a report is actively generating
    # -------------------------------------------------------------------------
    context "when the app has a report actively generating (BRA-75)" do
      before do
        make_member(role: :admin)
        sign_in user
      end

      %i[pending fetching analyzing].each do |in_progress_status|
        context "and the active report's status is #{in_progress_status}" do
          before { create(:report, app: the_app, status: in_progress_status) }

          it "renders 'Generate Report' as disabled" do
            get workspace_app_path(workspace, the_app)
            button = find_button(response.body, "Generate Report")
            expect(button["disabled"]).to be_present
          end

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
        end
      end

      context "when a report is in progress and a completed report already exists" do
        before do
          create(:report, app: the_app, status: :complete)
          create(:report, app: the_app, status: :analyzing)
        end

        it "renders all three buttons as disabled (in-progress overrides the completed history)" do
          get workspace_app_path(workspace, the_app)
          expect(find_button(response.body, "Generate Report")["disabled"]).to be_present
          expect(find_button(response.body, "Re-analyze existing reviews")["disabled"]).to be_present
          expect(find_button(response.body, "Refresh reviews + re-analyze")["disabled"]).to be_present
        end
      end

      context "when a report is in progress and NO completed report has ever existed (combined BRA-74 OR BRA-75)" do
        before { create(:report, app: the_app, status: :fetching) }

        it "renders all three buttons as disabled" do
          get workspace_app_path(workspace, the_app)
          expect(find_button(response.body, "Generate Report")["disabled"]).to be_present
          expect(find_button(response.body, "Re-analyze existing reviews")["disabled"]).to be_present
          expect(find_button(response.body, "Refresh reviews + re-analyze")["disabled"]).to be_present
        end
      end

      context "when refreshing the page mid-generation (server-rendered from DB, not just the live channel)" do
        before { create(:report, app: the_app, status: :fetching) }

        it "shows the buttons already disabled on a plain GET, with no turbo_stream/channel event involved" do
          get workspace_app_path(workspace, the_app)
          expect(find_button(response.body, "Generate Report")["disabled"]).to be_present
        end

        it "still exposes an in-progress report-id on the wrapper for the channel subscription to attach to" do
          active_report = the_app.reports.order(:created_at).last
          get workspace_app_path(workspace, the_app)
          wrapper = Nokogiri::HTML::Document.parse(response.body).at_css("#report_status")
          expect(wrapper["data-report-status-report-id-value"]).to eq(active_report.id.to_s)
        end
      end
    end

    # -------------------------------------------------------------------------
    # BRA-75: data-report-status-had-completed-report-value drives the
    # JS-only failed-state re-enable logic (Stimulus). Only the server-rendered
    # value itself is testable here.
    # -------------------------------------------------------------------------
    context "data-report-status-had-completed-report-value attribute" do
      before do
        make_member(role: :admin)
        sign_in user
      end

      def report_status_wrapper(body)
        Nokogiri::HTML::Document.parse(body).at_css("#report_status")
      end

      context "when a completed report already exists" do
        before { create(:report, app: the_app, status: :complete) }

        it "is set to true" do
          get workspace_app_path(workspace, the_app)
          wrapper = report_status_wrapper(response.body)
          expect(wrapper["data-report-status-had-completed-report-value"]).to eq("true")
        end
      end

      context "when no completed report has ever existed" do
        it "is set to false" do
          get workspace_app_path(workspace, the_app)
          wrapper = report_status_wrapper(response.body)
          expect(wrapper["data-report-status-had-completed-report-value"]).to eq("false")
        end
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

  # ---------------------------------------------------------------------------
  # GET /workspaces/:workspace_id/apps/:id/edit
  # ---------------------------------------------------------------------------
  describe "GET /workspaces/:workspace_id/apps/:id/edit" do
    let(:the_app) do
      create(:app, workspace: workspace,
                   app_store_id: "123456789", app_store_country: "us",
                   play_store_id: "com.example.myapp")
    end

    context "when signed in as an admin" do
      before do
        make_member(role: :admin)
        sign_in user
      end

      it "returns 200 OK" do
        get edit_workspace_app_path(workspace, the_app)
        expect(response).to have_http_status(:ok)
      end

      it "pre-fills the App Store URL field with the existing store id" do
        get edit_workspace_app_path(workspace, the_app)
        expect(response.body).to include("https://apps.apple.com/us/app/id123456789")
      end

      it "pre-fills the Play Store URL field with the existing store id" do
        get edit_workspace_app_path(workspace, the_app)
        expect(response.body).to include("https://play.google.com/store/apps/details?id=com.example.myapp")
      end
    end

    context "when signed in as a super_admin" do
      before do
        make_member(role: :super_admin)
        sign_in user
      end

      it "returns 200 OK" do
        get edit_workspace_app_path(workspace, the_app)
        expect(response).to have_http_status(:ok)
      end
    end

    context "when signed in as a collaborator" do
      before do
        make_member(role: :collaborator)
        sign_in user
      end

      it "returns 404" do
        get edit_workspace_app_path(workspace, the_app)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when not signed in" do
      it "redirects to sign in" do
        get edit_workspace_app_path(workspace, the_app)
        expect(response).to redirect_to(sign_in_path)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /workspaces/:workspace_id/apps/:id
  # ---------------------------------------------------------------------------
  describe "PATCH /workspaces/:workspace_id/apps/:id" do
    let(:the_app) do
      create(:app, workspace: workspace,
                   app_store_id: "123456789", app_store_country: "us",
                   play_store_id: "com.example.myapp")
    end

    context "when signed in as an admin" do
      before do
        make_member(role: :admin)
        sign_in user
      end

      it "updates the app's name" do
        patch workspace_app_path(workspace, the_app), params: {
          app: { name: "Renamed App",
                 app_store_url: "https://apps.apple.com/us/app/my-great-app/id123456789",
                 play_store_url: "https://play.google.com/store/apps/details?id=com.example.myapp" }
        }
        expect(the_app.reload.name).to eq("Renamed App")
      end

      it "redirects to the app show page" do
        patch workspace_app_path(workspace, the_app), params: {
          app: { name: "Renamed App",
                 app_store_url: "https://apps.apple.com/us/app/my-great-app/id123456789",
                 play_store_url: "https://play.google.com/store/apps/details?id=com.example.myapp" }
        }
        expect(response).to redirect_to(workspace_app_path(workspace, the_app))
      end

      it "saves successfully when the App Store URL is resubmitted exactly as pre-filled by the edit form" do
        original_app_store_id = the_app.app_store_id
        prefilled_url = "https://apps.apple.com/#{the_app.app_store_country}/app/id#{the_app.app_store_id}"
        patch workspace_app_path(workspace, the_app), params: {
          app: { name: "Renamed App", app_store_url: prefilled_url,
                 play_store_url: "https://play.google.com/store/apps/details?id=com.example.myapp" }
        }
        expect(response).to redirect_to(workspace_app_path(workspace, the_app))
        expect(the_app.reload.name).to eq("Renamed App")
        expect(the_app.app_store_id).to eq(original_app_store_id)
      end

      context "adding an App Store URL where none was set" do
        let(:the_app) { create(:app, workspace: workspace, app_store_id: nil, play_store_id: "com.example.myapp") }

        it "sets the app_store_id" do
          patch workspace_app_path(workspace, the_app), params: {
            app: { name: the_app.name, app_store_url: "https://apps.apple.com/gb/app/thing/id555000111",
                   play_store_url: "https://play.google.com/store/apps/details?id=com.example.myapp" }
          }
          expect(the_app.reload.app_store_id).to eq("555000111")
        end
      end

      context "adding a Play Store URL where none was set" do
        let(:the_app) { create(:app, workspace: workspace, app_store_id: "123456789", play_store_id: nil) }

        it "sets the play_store_id" do
          patch workspace_app_path(workspace, the_app), params: {
            app: { name: the_app.name, app_store_url: "https://apps.apple.com/us/app/my-great-app/id123456789",
                   play_store_url: "https://play.google.com/store/apps/details?id=com.new.app" }
          }
          expect(the_app.reload.play_store_id).to eq("com.new.app")
        end
      end

      context "replacing an existing App Store URL with a different one" do
        it "updates the app_store_id and app_store_country" do
          patch workspace_app_path(workspace, the_app), params: {
            app: { name: the_app.name, app_store_url: "https://apps.apple.com/gb/app/other/id999888777",
                   play_store_url: "https://play.google.com/store/apps/details?id=com.example.myapp" }
          }
          the_app.reload
          expect(the_app.app_store_id).to eq("999888777")
          expect(the_app.app_store_country).to eq("gb")
        end
      end

      context "replacing an existing Play Store URL with a different one" do
        it "updates the play_store_id" do
          patch workspace_app_path(workspace, the_app), params: {
            app: { name: the_app.name, app_store_url: "https://apps.apple.com/us/app/my-great-app/id123456789",
                   play_store_url: "https://play.google.com/store/apps/details?id=com.replaced.app" }
          }
          expect(the_app.reload.play_store_id).to eq("com.replaced.app")
        end
      end

      context "clearing the App Store URL while the Play Store URL remains" do
        it "nulls the app_store_id and app_store_country" do
          patch workspace_app_path(workspace, the_app), params: {
            app: { name: the_app.name, app_store_url: "",
                   play_store_url: "https://play.google.com/store/apps/details?id=com.example.myapp" }
          }
          the_app.reload
          expect(the_app.app_store_id).to be_nil
          expect(the_app.app_store_country).to be_nil
        end

        it "redirects to the app show page" do
          patch workspace_app_path(workspace, the_app), params: {
            app: { name: the_app.name, app_store_url: "",
                   play_store_url: "https://play.google.com/store/apps/details?id=com.example.myapp" }
          }
          expect(response).to redirect_to(workspace_app_path(workspace, the_app))
        end
      end

      context "clearing the Play Store URL while the App Store URL remains" do
        it "nulls the play_store_id" do
          patch workspace_app_path(workspace, the_app), params: {
            app: { name: the_app.name, app_store_url: "https://apps.apple.com/us/app/my-great-app/id123456789",
                   play_store_url: "" }
          }
          expect(the_app.reload.play_store_id).to be_nil
        end
      end

      context "clearing both store URLs" do
        it "does not save the app" do
          expect {
            patch workspace_app_path(workspace, the_app), params: {
              app: { name: the_app.name, app_store_url: "", play_store_url: "" }
            }
          }.not_to change { the_app.reload.updated_at }
        end

        it "returns 422 Unprocessable Entity" do
          patch workspace_app_path(workspace, the_app), params: {
            app: { name: the_app.name, app_store_url: "", play_store_url: "" }
          }
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "re-renders the edit form with the at_least_one_store_id validation error" do
          patch workspace_app_path(workspace, the_app), params: {
            app: { name: the_app.name, app_store_url: "", play_store_url: "" }
          }
          expect(response.body).to include("must have at least one of app_store_id or play_store_id")
        end
      end

      context "submitting an unrecognized App Store URL format" do
        let(:bad_app_store_url) { "https://not-a-real-apple-url.com/app/thing" }

        it "does not update the app_store_id" do
          patch workspace_app_path(workspace, the_app), params: {
            app: { name: the_app.name, app_store_url: bad_app_store_url,
                   play_store_url: "https://play.google.com/store/apps/details?id=com.example.myapp" }
          }
          expect(the_app.reload.app_store_id).to eq("123456789")
        end

        it "returns 422 Unprocessable Entity" do
          patch workspace_app_path(workspace, the_app), params: {
            app: { name: the_app.name, app_store_url: bad_app_store_url,
                   play_store_url: "https://play.google.com/store/apps/details?id=com.example.myapp" }
          }
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "shows the 'URL format not recognized' error message" do
          patch workspace_app_path(workspace, the_app), params: {
            app: { name: the_app.name, app_store_url: bad_app_store_url,
                   play_store_url: "https://play.google.com/store/apps/details?id=com.example.myapp" }
          }
          expect(response.body).to include("App Store URL format not recognized")
        end
      end

      context "submitting an unrecognized Play Store URL format" do
        let(:bad_play_store_url) { "https://play.google.com/store/apps/details" }

        it "does not update the play_store_id" do
          patch workspace_app_path(workspace, the_app), params: {
            app: { name: the_app.name, app_store_url: "https://apps.apple.com/us/app/my-great-app/id123456789",
                   play_store_url: bad_play_store_url }
          }
          expect(the_app.reload.play_store_id).to eq("com.example.myapp")
        end

        it "shows the 'URL format not recognized' error message" do
          patch workspace_app_path(workspace, the_app), params: {
            app: { name: the_app.name, app_store_url: "https://apps.apple.com/us/app/my-great-app/id123456789",
                   play_store_url: bad_play_store_url }
          }
          expect(response.body).to include("Play Store URL format not recognized")
        end
      end
    end

    context "when signed in as a collaborator" do
      before do
        make_member(role: :collaborator)
        sign_in user
      end

      it "returns 404" do
        patch workspace_app_path(workspace, the_app), params: {
          app: { name: "Renamed by collaborator" }
        }
        expect(response).to have_http_status(:not_found)
      end

      it "does not update the app's name" do
        expect {
          patch workspace_app_path(workspace, the_app), params: {
            app: { name: "Renamed by collaborator" }
          }
        }.not_to change { the_app.reload.name }
      end
    end

    context "when not signed in" do
      it "redirects to sign in" do
        patch workspace_app_path(workspace, the_app), params: { app: { name: "x" } }
        expect(response).to redirect_to(sign_in_path)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /workspaces/:workspace_id/apps/:id
  # ---------------------------------------------------------------------------
  describe "DELETE /workspaces/:workspace_id/apps/:id" do
    let(:the_app) { create(:app, workspace: workspace) }

    context "when signed in as an admin" do
      before do
        make_member(role: :admin)
        sign_in user
      end

      it "deletes the app" do
        the_app
        expect {
          delete workspace_app_path(workspace, the_app)
        }.to change(App, :count).by(-1)
      end

      it "redirects to the workspace path with a see_other status" do
        delete workspace_app_path(workspace, the_app)
        expect(response).to redirect_to(workspace_path(workspace))
        expect(response).to have_http_status(:see_other)
      end

      context "with reviews, reports, and notifications attached" do
        let!(:review) { create(:review, app: the_app) }
        let!(:report) { create(:report, app: the_app, status: :complete) }
        let!(:notification) { create(:notification, report: report, workspace: workspace, user: user) }

        it "cascades to destroy the app's reviews" do
          expect {
            delete workspace_app_path(workspace, the_app)
          }.to change(Review, :count).by(-1)
        end

        it "cascades to destroy the app's reports" do
          expect {
            delete workspace_app_path(workspace, the_app)
          }.to change(Report, :count).by(-1)
        end

        it "cascades to destroy notifications tied to the app's reports" do
          expect {
            delete workspace_app_path(workspace, the_app)
          }.to change(Notification, :count).by(-1)
        end

        it "does not raise ActiveRecord::InvalidForeignKey" do
          expect {
            delete workspace_app_path(workspace, the_app)
          }.not_to raise_error
        end
      end
    end

    context "when signed in as a super_admin" do
      before do
        make_member(role: :super_admin)
        sign_in user
      end

      it "deletes the app" do
        the_app
        expect {
          delete workspace_app_path(workspace, the_app)
        }.to change(App, :count).by(-1)
      end
    end

    context "when signed in as a collaborator" do
      before do
        make_member(role: :collaborator)
        sign_in user
      end

      it "returns 404" do
        delete workspace_app_path(workspace, the_app)
        expect(response).to have_http_status(:not_found)
      end

      it "does not delete the app" do
        the_app
        expect {
          delete workspace_app_path(workspace, the_app)
        }.not_to change(App, :count)
      end
    end

    context "when not signed in" do
      it "redirects to sign in" do
        delete workspace_app_path(workspace, the_app)
        expect(response).to redirect_to(sign_in_path)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Edit/Delete entry points on the app show page — visibility by role
  # ---------------------------------------------------------------------------
  describe "Edit/Delete entry points on the app show page" do
    let(:the_app) { create(:app, workspace: workspace) }

    def find_edit_link(body)
      Nokogiri::HTML::Document.parse(body).css("a.icon-btn--edit").first
    end

    def find_delete_trigger_button(body)
      Nokogiri::HTML::Document.parse(body).css("button.icon-btn--delete").first
    end

    context "when signed in as an admin" do
      before do
        make_member(role: :admin)
        sign_in user
      end

      it "renders the Edit App icon link" do
        get workspace_app_path(workspace, the_app)
        expect(find_edit_link(response.body)).to be_present
      end

      it "renders the Delete App icon button that opens the delete confirmation modal" do
        get workspace_app_path(workspace, the_app)
        button = find_delete_trigger_button(response.body)
        expect(button["data-action"]).to eq("click->delete-modal#open")
      end
    end

    context "when signed in as a collaborator" do
      before do
        make_member(role: :collaborator)
        sign_in user
      end

      it "does not render the Edit App icon link" do
        get workspace_app_path(workspace, the_app)
        expect(find_edit_link(response.body)).to be_nil
      end

      it "does not render the Delete App icon button" do
        get workspace_app_path(workspace, the_app)
        expect(find_delete_trigger_button(response.body)).to be_nil
      end
    end
  end
end
