# frozen_string_literal: true

require "rails_helper"

RSpec.describe Notifications::MarkAllReadService, type: :service do
  let(:workspace)  { create(:workspace) }
  let(:app_record) { create(:app, workspace: workspace) }
  let(:report)     { create(:report, app: app_record) }
  let(:user)       { create(:user) }

  subject(:call) { described_class.call(user: user) }

  context "when the user has unread notifications" do
    let!(:unread_one) do
      create(:notification, user: user, workspace: workspace, report: report, read_at: nil)
    end
    let!(:unread_two) do
      create(:notification, user: user, workspace: workspace, report: report, read_at: nil)
    end

    it "sets read_at on all unread notifications for the user" do
      call
      expect(unread_one.reload.read_at).not_to be_nil
      expect(unread_two.reload.read_at).not_to be_nil
    end

    it "results in zero unread notifications for the user" do
      call
      expect(Notification.unread_count_for(user)).to eq(0)
    end
  end

  context "when the notification already has a read_at" do
    let(:original_read_at) { 5.days.ago }
    let!(:already_read) do
      create(:notification, user: user, workspace: workspace, report: report, read_at: original_read_at)
    end

    it "does not change the existing read_at" do
      call
      expect(already_read.reload.read_at).to be_within(1.second).of(original_read_at)
    end
  end

  context "when another user has unread notifications" do
    let(:other_user) { create(:user) }
    let!(:other_users_unread) do
      create(:notification, user: other_user, workspace: workspace, report: report, read_at: nil)
    end

    it "does not mark the other user's notifications as read" do
      call
      expect(other_users_unread.reload.read_at).to be_nil
    end
  end
end
