# frozen_string_literal: true

require "rails_helper"
require "cgi"

# BRA-39: Notification bell — unread badge, dropdown list, mark as read
RSpec.describe "Notification bell", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user)      { create(:user) }
  let(:workspace) { create(:workspace) }
  let(:app_record) { create(:app, workspace: workspace) }
  let(:report)    { create(:report, app: app_record) }

  before { sign_in user }

  # ---------------------------------------------------------------------------
  # AC: Bell badge shows correct unread count on page load
  # ---------------------------------------------------------------------------
  describe "unread count badge" do
    before do
      create_list(:notification, 2, user: user, workspace: workspace, report: report, read_at: nil)
      create(:notification, user: user, workspace: workspace, report: report, read_at: Time.current)
    end

    it "shows only the unread count in the badge" do
      get root_path
      expect(response.body).to include(
        %(data-notification-badge-target="count">2<)
      )
    end
  end

  # ---------------------------------------------------------------------------
  # AC: Badge disappears when count reaches 0
  # ---------------------------------------------------------------------------
  describe "badge visibility" do
    context "when the user has 0 unread notifications" do
      it "renders the badge span with the is-hidden class" do
        get root_path
        expect(response.body).to match(/class="notification-badge\s+is-hidden"/)
      end
    end

    context "when the user has unread notifications" do
      before do
        create(:notification, user: user, workspace: workspace, report: report, read_at: nil)
      end

      it "does not render the badge span with the is-hidden class" do
        get root_path
        expect(response.body).not_to match(/class="notification-badge\s+is-hidden"/)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Guard against regressing the bug where the bell trigger itself was hidden
  # ---------------------------------------------------------------------------
  describe "bell trigger visibility" do
    it "always renders the bell trigger, even with 0 unread notifications" do
      get root_path
      expect(response.body).to include('class="notification-bell-trigger"')
    end
  end

  # ---------------------------------------------------------------------------
  # Dropdown contents
  # ---------------------------------------------------------------------------
  describe "notification dropdown list" do
    context "when the user has notifications" do
      let!(:notification) do
        create(:notification,
               user: user, workspace: workspace, report: report,
               message: "Your report is ready", read_at: nil)
      end

      it "renders the notification's message" do
        get root_path
        expect(response.body).to include(CGI.escapeHTML(notification.message))
      end

      it "renders the notification's workspace name" do
        get root_path
        expect(response.body).to include(CGI.escapeHTML(workspace.name))
      end

      it "renders a relative time-ago string" do
        get root_path
        expect(response.body).to include("ago")
      end

      # -------------------------------------------------------------------
      # BRA-76: the list container/empty-state need stable ids so live
      # Turbo Stream broadcasts (broadcast_remove_to / broadcast_prepend_to)
      # can target them without a full page reload.
      # -------------------------------------------------------------------
      it "renders the list container with id=notification_list" do
        get root_path
        expect(response.body).to include('id="notification_list"')
      end

      # -------------------------------------------------------------------
      # BRA-76: the item must be rendered from the shared
      # notifications/notification partial — proven here by asserting the
      # item is wired to a real, persisted notification's notification_path
      # (not an in-memory hash without an id), matching exactly what the
      # partial itself produces.
      # -------------------------------------------------------------------
      it "wires the notification item's form action to the real, persisted notification_path" do
        get root_path
        expect(response.body).to include(%(action="#{notification_path(notification)}"))
      end

      it "renders the unread notification with the notification-item--unread class, as the partial does" do
        get root_path
        expect(response.body).to include("notification-item notification-item--unread")
      end
    end

    context "when the user has more than 10 notifications" do
      let!(:newest) do
        create(:notification, user: user, workspace: workspace, report: report,
               message: "Newest notification", created_at: 1.minute.ago)
      end

      before do
        create_list(:notification, 10, user: user, workspace: workspace, report: report,
                    message: "Older notification", created_at: 1.day.ago)
      end

      it "renders only the 10 most recent notifications" do
        get root_path
        expect(response.body.scan("notification-item-message").size).to eq(10)
      end

      it "includes the most recent notification" do
        get root_path
        expect(response.body).to include(CGI.escapeHTML(newest.message))
      end
    end

    context "when the user has zero notifications" do
      it "renders the empty state message" do
        get root_path
        expect(response.body).to include("No notifications yet.")
      end

      # BRA-76: the empty-state element needs id=notification_empty so a
      # live-broadcast notification's Turbo Stream remove action can target it.
      it "renders the empty state paragraph with id=notification_empty" do
        get root_path
        expect(response.body).to include('id="notification_empty"')
      end
    end
  end
end
