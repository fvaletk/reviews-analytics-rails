# frozen_string_literal: true

class ReportJob < ApplicationJob
  queue_as :default

  MAX_REVIEWS_PER_ANALYSIS = 500

  def perform(report_id, skip_scraping: false)
    report = Report.find(report_id)
    app = report.app

    if skip_scraping
      reviews_for_analysis = app.reviews.order(reviewed_at: :desc).limit(MAX_REVIEWS_PER_ANALYSIS)
      total_reviews_analyzed = reviews_for_analysis.size
    else
      update_status(report, :fetching)

      raw = ScrapingService.fetch(
        app_store_id: app.app_store_id,
        app_store_country: app.app_store_country,
        play_store_id: app.play_store_id
      )

      reviews_data = build_review_records(raw["reviews"] || [], app.id)
      Review.insert_all(reviews_data, unique_by: [:app_id, :store, :external_id]) if reviews_data.any?

      reviews_for_analysis = Review.where(app: app).order(reviewed_at: :desc).limit(MAX_REVIEWS_PER_ANALYSIS)
      total_reviews_analyzed = reviews_data.size
    end

    if reviews_for_analysis.size == MAX_REVIEWS_PER_ANALYSIS
      Rails.logger.info("[ReportJob] review cap applied — #{MAX_REVIEWS_PER_ANALYSIS} of #{Review.where(app: app).count} reviews used for app #{app.id}")
    end

    update_status(report, :analyzing)

    result = LlmService.analyze(reviews: reviews_for_analysis)
    ReportSchemaValidator.validate!(result)

    app_store_reviews_count, play_store_reviews_count = store_breakdown(reviews_for_analysis)

    report.update!(
      structured_output: result,
      status: :complete,
      total_reviews_analyzed: total_reviews_analyzed,
      reviews_fetched_at: Time.current,
      app_store_reviews_count: app_store_reviews_count,
      play_store_reviews_count: play_store_reviews_count
    )
    broadcast(report)
    notify_workspace_members(report, app, "Report for #{app.name} is ready.")
  rescue ScrapingService::Error, StandardError => e
    report&.update(status: :failed, failure_reason: e.message)
    broadcast(report) if report
    notify_workspace_members(report, app, "Report for #{app.name} failed: #{e.message}") if report
  end

  private

  def store_breakdown(reviews)
    counts = reviews.pluck(:store).tally
    [counts["app_store"] || 0, counts["play_store"] || 0]
  end

  def update_status(report, status)
    report.update!(status: status)
    broadcast(report)
  end

  def broadcast(report)
    ActionCable.server.broadcast(
      "report_#{report.id}",
      { status: report.status, failure_reason: report.failure_reason }
    )
  end

  def notify_workspace_members(report, app, message)
    now = Time.current
    user_ids = app.workspace.workspace_memberships.pluck(:user_id)

    notification_records = user_ids.map do |user_id|
      {
        user_id: user_id,
        workspace_id: app.workspace_id,
        report_id: report.id,
        message: message,
        read_at: nil,
        created_at: now,
        updated_at: now
      }
    end

    Notification.insert_all(notification_records) if notification_records.any?

    user_ids.each do |user_id|
      broadcast_notification(user_id)
    end
  end

  def broadcast_notification(user_id)
    user = User.find(user_id)

    ActionCable.server.broadcast(
      "notifications_user_#{user_id}",
      { unread_count: Notification.unread_count_for(user) }
    )
  end

  def build_review_records(reviews, app_id)
    now = Time.current
    reviews.map do |r|
      {
        app_id: app_id,
        store: Review.stores[r["store"]],
        external_id: r["external_id"],
        author: r["author"],
        rating: r["rating"],
        title: r["title"],
        body: r["body"],
        reviewed_at: r["reviewed_at"],
        fetched_at: now,
        created_at: now,
        updated_at: now
      }
    end
  end
end
