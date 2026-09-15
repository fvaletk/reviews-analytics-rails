# frozen_string_literal: true

class Report < ApplicationRecord
  belongs_to :app
  belongs_to :generated_by, class_name: "User", foreign_key: :generated_by_user_id

  has_many :notifications, dependent: :destroy

  enum :status, { pending: 0, fetching: 1, analyzing: 2, complete: 3, failed: 4 }
  enum :report_type, { generate: 0, refresh: 1, reanalyze: 2 }

  validates :status, presence: true

  after_commit :enqueue_icp_extraction, on: :update

  private

  def enqueue_icp_extraction
    return unless saved_change_to_status? && complete?
    return if app.icp_extraction_attempted?
    return if app.reports.complete.where.not(id: id).exists?

    IcpExtractionJob.perform_later(app_id)
  rescue StandardError => e
    Rails.logger.error("[Report##{id}] ICP enqueue failed: #{e.message}")
  end
end
