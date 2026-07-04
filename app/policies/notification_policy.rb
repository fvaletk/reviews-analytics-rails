# frozen_string_literal: true

class NotificationPolicy < ApplicationPolicy
  # record is a Notification instance (or the Notification class for mark_all_read?)

  def update?
    record.user_id == user.id
  end

  def mark_all_read?
    # The controller always scopes the underlying query to current_user's own
    # notifications, so any signed-in user may mark all of their own as read.
    true
  end
end
