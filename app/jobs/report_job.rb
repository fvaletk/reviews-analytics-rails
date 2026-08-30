# frozen_string_literal: true

class ReportJob < ApplicationJob
  queue_as :default

  MAX_REVIEWS_TOTAL     = 500  # unchanged from BRA-73 — worst-case prompt size is identical
  MAX_REVIEWS_PER_STORE = 250  # provisional: TOTAL / 2, pending recalibration in BRA-85

  def perform(report_id, skip_scraping: false)
    report = Report.find(report_id)
    app = report.app

    if skip_scraping
      app_store_reviews, play_store_reviews = select_reviews_for_analysis(app.reviews)
    else
      update_status(report, :fetching)

      raw = ScrapingService.fetch(
        app_store_id: app.app_store_id,
        app_store_country: app.app_store_country,
        play_store_id: app.play_store_id
      )

      reviews_data = build_review_records(raw["reviews"] || [], app.id)
      Review.insert_all(reviews_data, unique_by: [ :app_id, :store, :external_id ]) if reviews_data.any?

      app_store_reviews, play_store_reviews = select_reviews_for_analysis(Review.where(app: app))
    end

    reviews_for_analysis = app_store_reviews + play_store_reviews
    total_reviews_analyzed = reviews_for_analysis.size

    log_review_cap(app, :app_store, app_store_reviews)
    log_review_cap(app, :play_store, play_store_reviews)

    update_status(report, :analyzing)

    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = LlmService.analyze(reviews: reviews_for_analysis)
    llm_duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round

    ReportSchemaValidator.validate!(result.data)

    app_store_reviews_count, play_store_reviews_count = store_breakdown(reviews_for_analysis)

    input_tokens = result.usage["promptTokenCount"]
    output_tokens = result.usage["candidatesTokenCount"]
    thinking_tokens = result.usage["thoughtsTokenCount"]
    model = LlmService::MODEL
    cost_usd = (input_tokens && output_tokens) ? LlmService.cost_usd(model: model, input_tokens: input_tokens, output_tokens: output_tokens) : nil

    report.update!(
      structured_output: result.data,
      status: :complete,
      total_reviews_analyzed: total_reviews_analyzed,
      reviews_fetched_at: Time.current,
      app_store_reviews_count: app_store_reviews_count,
      play_store_reviews_count: play_store_reviews_count,
      model: model,
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      thinking_tokens: thinking_tokens,
      llm_duration_ms: llm_duration_ms,
      cost_usd: cost_usd,
      usage_metadata: result.usage
    )
    broadcast(report)
    notify_workspace_members(report, app, "Report for #{app.name} is ready.")
  rescue ScrapingService::Error, StandardError => e
    report&.update(status: :failed, failure_reason: e.message)
    broadcast(report) if report
    notify_workspace_members(report, app, "Report for #{app.name} failed: #{e.message}") if report
  end

  private

  # Selects up to MAX_REVIEWS_PER_STORE reviews from each store (most recent
  # first), then spills any unused per-store allocation to whichever store(s)
  # still have more reviews, up to MAX_REVIEWS_TOTAL combined. This ensures an
  # app with reviews in only one store still receives up to MAX_REVIEWS_TOTAL
  # reviews from that store, while a healthy mix of both stores never lets one
  # store crowd the other out below its allotment.
  def select_reviews_for_analysis(scope)
    app_store_scope  = scope.app_store
    play_store_scope = scope.play_store

    app_store_reviews  = app_store_scope.order(reviewed_at: :desc).limit(MAX_REVIEWS_PER_STORE).to_a
    play_store_reviews = play_store_scope.order(reviewed_at: :desc).limit(MAX_REVIEWS_PER_STORE).to_a

    remaining = MAX_REVIEWS_TOTAL - app_store_reviews.size - play_store_reviews.size

    if remaining > 0
      extra_app_store = app_store_scope.order(reviewed_at: :desc).offset(app_store_reviews.size).limit(remaining).to_a
      remaining -= extra_app_store.size
      extra_play_store = remaining > 0 ? play_store_scope.order(reviewed_at: :desc).offset(play_store_reviews.size).limit(remaining).to_a : []

      app_store_reviews += extra_app_store
      play_store_reviews += extra_play_store
    end

    [ app_store_reviews, play_store_reviews ]
  end

  # Logs only when the store's cap was actually binding, i.e. some of that
  # store's reviews were excluded from analysis (including a store that used
  # up its own allotment and also absorbed the other store's spillover).
  def log_review_cap(app, store, selected_reviews)
    total = Review.where(app: app).public_send(store).count
    return if selected_reviews.size >= total

    Rails.logger.info("[ReportJob] #{store} review cap applied — #{selected_reviews.size} of #{total} reviews used for app #{app.id}")
  end

  def store_breakdown(reviews)
    counts = reviews.pluck(:store).tally
    [ counts["app_store"] || 0, counts["play_store"] || 0 ]
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

    return if notification_records.empty?

    Notification.insert_all(notification_records)

    # insert_all bypasses callbacks and returns no model instances, but the
    # broadcast partial needs a real persisted id (for notification_path).
    # Every row in this batch shares the same `now` timestamp, so this scopes
    # cleanly to exactly the rows just inserted.
    persisted_notifications = Notification.where(report_id: report.id, created_at: now).index_by(&:user_id)

    user_ids.each do |user_id|
      broadcast_notification(user_id, persisted_notifications[user_id])
    end
  end

  def broadcast_notification(user_id, notification)
    user = User.find(user_id)

    ActionCable.server.broadcast(
      "notifications_user_#{user_id}",
      { unread_count: Notification.unread_count_for(user) }
    )

    return unless notification

    # Remove the "No notifications yet." empty-state element (if present)
    # before prepending the first live notification, so the two don't
    # render side by side.
    Turbo::StreamsChannel.broadcast_remove_to(user, :notifications, target: "notification_empty")

    Turbo::StreamsChannel.broadcast_prepend_to(
      user,
      :notifications,
      target: "notification_list",
      partial: "notifications/notification",
      locals: { notification: notification }
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
