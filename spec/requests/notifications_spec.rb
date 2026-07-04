# frozen_string_literal: true

require "rails_helper"

# BRA-39: Notifications controller — mark as read / mark all as read
RSpec.describe "Notifications", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user)       { create(:user) }
  let(:workspace)  { create(:workspace) }
  let(:app_record) { create(:app, workspace: workspace) }
  let(:report)     { create(:report, app: app_record) }

  describe "PATCH /notifications/:id" do
    context "when signed in" do
      before { sign_in user }

      let(:notification) do
        create(:notification, user: user, workspace: workspace, report: report, read_at: nil)
      end

      it "marks the notification's read_at" do
        patch notification_path(notification)
        expect(notification.reload.read_at).not_to be_nil
      end

      it "redirects to the report page" do
        patch notification_path(notification)
        expect(response).to redirect_to(workspace_app_report_path(workspace, app_record, report))
      end

      context "when the notification belongs to another user" do
        let(:other_user) { create(:user) }
        let(:other_notification) do
          create(:notification, user: other_user, workspace: workspace, report: report, read_at: nil)
        end

        it "returns 404" do
          patch notification_path(other_notification)
          expect(response).to have_http_status(:not_found)
        end

        it "does not mark the other user's notification as read" do
          patch notification_path(other_notification)
          expect(other_notification.reload.read_at).to be_nil
        end
      end
    end

    context "when not signed in" do
      let(:notification) do
        create(:notification, user: user, workspace: workspace, report: report, read_at: nil)
      end

      it "redirects to sign_in_path" do
        patch notification_path(notification)
        expect(response).to redirect_to(sign_in_path)
      end
    end
  end

  describe "PATCH /notifications/mark_all_read" do
    before { sign_in user }

    let!(:unread_one) do
      create(:notification, user: user, workspace: workspace, report: report, read_at: nil)
    end
    let!(:unread_two) do
      create(:notification, user: user, workspace: workspace, report: report, read_at: nil)
    end
    let(:original_read_at) { 3.days.ago }
    let!(:already_read) do
      create(:notification, user: user, workspace: workspace, report: report, read_at: original_read_at)
    end
    let(:other_user) { create(:user) }
    let!(:other_users_unread) do
      create(:notification, user: other_user, workspace: workspace, report: report, read_at: nil)
    end

    it "sets read_at on all of the current user's unread notifications" do
      patch mark_all_read_notifications_path
      expect(unread_one.reload.read_at).not_to be_nil
      expect(unread_two.reload.read_at).not_to be_nil
    end

    it "does not change the read_at of already-read notifications" do
      patch mark_all_read_notifications_path
      expect(already_read.reload.read_at).to be_within(1.second).of(original_read_at)
    end

    it "does not touch another user's unread notifications" do
      patch mark_all_read_notifications_path
      expect(other_users_unread.reload.read_at).to be_nil
    end

    it "results in an unread count of 0 for the current user" do
      patch mark_all_read_notifications_path
      expect(Notification.unread_count_for(user)).to eq(0)
    end

    it "redirects back" do
      patch mark_all_read_notifications_path, headers: { "HTTP_REFERER" => root_path }
      expect(response).to redirect_to(root_path)
    end
  end
end
