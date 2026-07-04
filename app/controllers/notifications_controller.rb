# frozen_string_literal: true

class NotificationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_notification, only: [:update]

  def update
    authorize @notification

    Notifications::MarkAsReadService.call(notification: @notification)

    redirect_to workspace_app_report_path(
      @notification.report.app.workspace,
      @notification.report.app,
      @notification.report
    )
  end

  def mark_all_read
    authorize Notification

    Notifications::MarkAllReadService.call(user: current_user)

    redirect_back fallback_location: root_path
  end

  private

  def set_notification
    @notification = current_user.notifications.find(params[:id])
  end
end
