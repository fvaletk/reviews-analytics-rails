# frozen_string_literal: true

require "rails_helper"

RSpec.describe Notifications::MarkAsReadService, type: :service do
  let(:workspace)  { create(:workspace) }
  let(:app_record) { create(:app, workspace: workspace) }
  let(:report)     { create(:report, app: app_record) }
  let(:user)       { create(:user) }
  let(:notification) do
    create(:notification, user: user, workspace: workspace, report: report, read_at: nil)
  end

  subject(:call) { described_class.call(notification: notification) }

  it "sets read_at on the notification" do
    call
    expect(notification.reload.read_at).not_to be_nil
  end

  it "returns the notification" do
    expect(call).to eq(notification)
  end

  context "when the notification is already read" do
    let(:original_read_at) { 2.days.ago }
    let(:notification) do
      create(:notification, user: user, workspace: workspace, report: report, read_at: original_read_at)
    end

    it "updates read_at to the current time" do
      call
      expect(notification.reload.read_at).to be_within(1.second).of(Time.current)
    end
  end
end
