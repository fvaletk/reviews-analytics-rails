# frozen_string_literal: true

class ScrapingService
  Error = Class.new(StandardError)

  TIMEOUT_SECONDS = 120

  def self.fetch(app_store_id:, app_store_country:, play_store_id:, max_reviews: 500)
    connection = Faraday.new(url: ENV.fetch("SCRAPING_SERVICE_URL")) do |f|
      f.options.timeout = TIMEOUT_SECONDS
      f.options.open_timeout = TIMEOUT_SECONDS
      f.request :json
      f.response :json
    end

    response = connection.post("/scrape") do |req|
      req.body = {
        app_store_id: app_store_id,
        app_store_country: app_store_country,
        play_store_id: play_store_id,
        max_reviews: max_reviews
      }
    end

    raise Error, "HTTP #{response.status}" unless response.success?

    response.body
  rescue Faraday::TimeoutError => e
    raise Error, "Request timed out: #{e.message}"
  rescue Faraday::Error => e
    raise Error, e.message
  end
end
