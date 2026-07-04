# frozen_string_literal: true

module Notifications
  class MarkAllReadService
    def self.call(user:)
      new(user: user).call
    end

    def initialize(user:)
      @user = user
    end

    def call
      user.notifications.unread.update_all(read_at: Time.current)
    end

    private

    attr_reader :user
  end
end
