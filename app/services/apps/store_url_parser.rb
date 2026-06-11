# frozen_string_literal: true

module Apps
  class StoreUrlParser
    APP_STORE_REGEX = %r{
      \Ahttps?://(?:apps|itunes)\.apple\.com/
      ([a-z]{2})/         # country code
      app/[^/]+/          # app name slug
      id(\d+)             # numeric app id
    }x

    PLAY_STORE_REGEX = %r{
      \Ahttps?://play\.google\.com/store/apps/details
    }x

    def self.call(url)
      new(url).call
    end

    def initialize(url)
      @url = url.to_s.strip
    end

    def call
      parse_app_store || parse_play_store
    end

    private

    def parse_app_store
      match = APP_STORE_REGEX.match(@url)
      return nil unless match

      { app_store_id: match[2], app_store_country: match[1] }
    end

    def parse_play_store
      return nil unless PLAY_STORE_REGEX.match?(@url)

      uri = URI.parse(@url)
      params = URI.decode_www_form(uri.query.to_s).to_h
      play_store_id = params["id"]

      return nil if play_store_id.nil? || play_store_id.empty?

      { play_store_id: play_store_id }
    end
  end
end
