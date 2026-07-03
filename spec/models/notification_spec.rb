# frozen_string_literal: true

require "rails_helper"

RSpec.describe Notification, type: :model do
  describe "associations" do
    it "belongs to a user" do
      notification = build(:notification)
      expect(notification.user).to be_present
    end

    it "belongs to a workspace" do
      notification = build(:notification)
      expect(notification.workspace).to be_present
    end

    it "belongs to a report" do
      notification = build(:notification)
      expect(notification.report).to be_present
    end
  end

  describe "validations" do
    it "is valid with a user, workspace, report, and message" do
      notification = build(:notification)
      expect(notification).to be_valid
    end

    it "is invalid without a message" do
      notification = build(:notification, message: nil)
      expect(notification).not_to be_valid
    end
  end

  describe ".unread" do
    it "returns only records with read_at: nil" do
      unread_notification = create(:notification, read_at: nil)
      create(:notification, read_at: Time.current)

      expect(Notification.unread).to contain_exactly(unread_notification)
    end
  end

  describe ".unread_count_for" do
    it "returns the count of unread notifications belonging to the given user only" do
      target_user = create(:user)
      other_user = create(:user)

      create(:notification, user: target_user, read_at: nil)
      create(:notification, user: target_user, read_at: nil)
      create(:notification, user: target_user, read_at: Time.current)
      create(:notification, user: other_user, read_at: nil)

      expect(Notification.unread_count_for(target_user)).to eq(2)
    end
  end
end
