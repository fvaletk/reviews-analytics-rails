# frozen_string_literal: true

class IcpExtractionJob < ApplicationJob
  queue_as :default

  def perform(app_id)
    app = App.find(app_id)
    return if app.icp_extraction_attempted?

    selection = ReviewSelector.select(app.reviews)
    reviews = selection.app_store + selection.play_store

    if reviews.empty?
      Rails.logger.info("[IcpExtractionJob] app #{app.id} has no eligible reviews for ICP extraction — skipping without persisting")
      return
    end

    result = LlmService.extract_icp(reviews: reviews)
    IcpSchemaValidator.validate!(result.data)

    persist(app, result)
  rescue LlmService::Error, LlmService::TruncatedResponseError, IcpSchemaValidator::InvalidSchema => e
    Rails.logger.error("[IcpExtractionJob] app #{app_id} ICP extraction failed: #{e.class}: #{e.message}")
  end

  private

  def persist(app, result)
    data = result.data
    primary_segment = fetch(data, "primary_segment")

    input_tokens = result.usage["promptTokenCount"]
    output_tokens = result.usage["candidatesTokenCount"]
    model = LlmService::MODEL
    cost_usd = (input_tokens && output_tokens) ? LlmService.cost_usd(model: model, input_tokens: input_tokens, output_tokens: output_tokens) : nil

    attributes = {
      icp_model: model,
      icp_input_tokens: input_tokens,
      icp_output_tokens: output_tokens,
      icp_cost_usd: cost_usd,
      icp_usage_metadata: result.usage,
      icp_generated_at: Time.current
    }

    if primary_segment.blank?
      attributes[:icp] = nil
      attributes[:icp_declined_reason] = fetch(data, "declined_reason")
    else
      attributes[:icp] = {
        primary_segment: primary_segment,
        confidence: fetch(data, "confidence"),
        signals: fetch(data, "signals")
      }
      attributes[:icp_declined_reason] = nil
    end

    app.update!(attributes)
  end

  def fetch(hash, key)
    hash.key?(key.to_s) ? hash[key.to_s] : hash[key.to_sym]
  end
end
