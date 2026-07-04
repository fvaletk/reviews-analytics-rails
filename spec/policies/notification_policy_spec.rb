# frozen_string_literal: true

require "rails_helper"

RSpec.describe NotificationPolicy, type: :policy do
  let(:workspace)  { create(:workspace) }
  let(:app_record) { create(:app, workspace: workspace) }
  let(:report)     { create(:report, app: app_record) }
  let(:owner)      { create(:user) }
  let(:notification) { create(:notification, user: owner, workspace: workspace, report: report) }

  describe "#update?" do
    subject(:policy) { described_class.new(user, notification) }

    context "when the user owns the notification" do
      let(:user) { owner }

      it "permits update?" do
        expect(policy.update?).to be true
      end
    end

    context "when the user does not own the notification" do
      let(:user) { create(:user) }

      it "denies update?" do
        expect(policy.update?).to be false
      end
    end
  end

  describe "#mark_all_read?" do
    subject(:policy) { described_class.new(user, Notification) }

    context "as any signed-in user" do
      let(:user) { create(:user) }

      it "permits mark_all_read?" do
        expect(policy.mark_all_read?).to be true
      end
    end
  end
end
