# frozen_string_literal: true

require "rails_helper"

RSpec.describe ScrapingService do
  let(:base_url) { "http://scraping:8000" }
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:connection) do
    Faraday.new do |f|
      f.request :json
      f.response :json
      f.adapter :test, stubs
    end
  end

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("SCRAPING_SERVICE_URL").and_return(base_url)
    allow(Faraday).to receive(:new).and_return(connection)
  end

  let(:params) do
    {
      app_store_id: "123456789",
      app_store_country: "us",
      play_store_id: nil
    }
  end

  describe ".fetch" do
    context "on a successful response" do
      let(:reviews_payload) do
        { "reviews" => [{ "external_id" => "r1", "author" => "Alice", "rating" => 5 }] }
      end

      before do
        stubs.post("/scrape") { [200, { "Content-Type" => "application/json" }, reviews_payload] }
      end

      it "returns the parsed response body" do
        result = described_class.fetch(**params)
        expect(result).to eq(reviews_payload)
      end
    end

    context "on an HTTP 500 error" do
      before do
        stubs.post("/scrape") { [500, {}, "Internal Server Error"] }
      end

      it "raises ScrapingService::Error with the status code" do
        expect { described_class.fetch(**params) }.to raise_error(ScrapingService::Error, /HTTP 500/)
      end
    end

    context "on a timeout" do
      before do
        stubs.post("/scrape") { raise Faraday::TimeoutError, "execution expired" }
      end

      it "raises ScrapingService::Error mentioning the timeout" do
        expect { described_class.fetch(**params) }.to raise_error(ScrapingService::Error, /timed out/)
      end
    end
  end

  describe "timeout configuration" do
    it "sets a 120 second timeout constant" do
      expect(ScrapingService::TIMEOUT_SECONDS).to eq(120)
    end
  end
end
