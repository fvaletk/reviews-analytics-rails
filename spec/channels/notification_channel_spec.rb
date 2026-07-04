# frozen_string_literal: true

require "rails_helper"

RSpec.describe NotificationChannel, type: :channel do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  before { stub_connection(current_user: user) }

  describe "#subscribed" do
    it "streams from the current user's own notification stream" do
      subscribe

      expect(subscription).to have_stream_from("notifications_user_#{user.id}")
    end

    it "does not stream from another user's notification stream" do
      subscribe

      expect(subscription).not_to have_stream_from("notifications_user_#{other_user.id}")
    end

    it "confirms the subscription" do
      subscribe

      expect(subscription).to be_confirmed
    end
  end

  describe "stream scoping between users" do
    it "receives a broadcast sent to its own user's stream" do
      subscribe

      expect {
        ActionCable.server.broadcast("notifications_user_#{user.id}", { unread_count: 2 })
      }.to have_broadcasted_to("notifications_user_#{user.id}").with(unread_count: 2)
    end

    it "is not affected by a broadcast sent to another user's stream" do
      subscribe

      expect {
        ActionCable.server.broadcast("notifications_user_#{other_user.id}", { unread_count: 5 })
      }.not_to have_broadcasted_to("notifications_user_#{user.id}")
    end
  end

  describe "#unsubscribed" do
    it "stops all streams" do
      subscribe

      expect { subscription.unsubscribe_from_channel }.not_to raise_error
    end
  end
end
