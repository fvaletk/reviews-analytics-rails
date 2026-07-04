# frozen_string_literal: true

module Notifications
  class MarkAsReadService
    def self.call(notification:)
      new(notification: notification).call
    end

    def initialize(notification:)
      @notification = notification
    end

    def call
      notification.update!(read_at: Time.current)
      notification
    end

    private

    attr_reader :notification
  end
end
