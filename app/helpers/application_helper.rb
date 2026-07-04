module ApplicationHelper
  def current_user_unread_notifications_count
    Notification.unread_count_for(current_user)
  end

  def current_user_recent_notifications
    current_user.notifications.order(created_at: :desc).limit(10)
  end
end
