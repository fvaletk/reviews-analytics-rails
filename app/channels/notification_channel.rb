# frozen_string_literal: true

class NotificationChannel < ApplicationCable::Channel
  def subscribed
    stream_from "notifications_user_#{current_user.id}"
  end

  def unsubscribed
    stop_all_streams
  end
end
