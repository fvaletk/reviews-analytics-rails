# frozen_string_literal: true

require "rails_helper"

RSpec.describe Apps::StoreUrlParser, type: :service do
  subject(:result) { described_class.call(url) }

  # ---------------------------------------------------------------------------
  # App Store — apps.apple.com
  # ---------------------------------------------------------------------------
  context "with an apps.apple.com URL" do
    let(:url) { "https://apps.apple.com/us/app/some-app-name/id1234567890" }

    it "returns the numeric app_store_id" do
      expect(result[:app_store_id]).to eq("1234567890")
    end

    it "returns the two-letter country code" do
      expect(result[:app_store_country]).to eq("us")
    end

    it "does not include a play_store_id key" do
      expect(result).not_to have_key(:play_store_id)
    end
  end

  # ---------------------------------------------------------------------------
  # App Store — itunes.apple.com
  # ---------------------------------------------------------------------------
  context "with an itunes.apple.com URL" do
    let(:url) { "https://itunes.apple.com/gb/app/app-name/id987654321" }

    it "returns the numeric app_store_id" do
      expect(result[:app_store_id]).to eq("987654321")
    end

    it "returns the two-letter country code" do
      expect(result[:app_store_country]).to eq("gb")
    end
  end

  # ---------------------------------------------------------------------------
  # Play Store — id only
  # ---------------------------------------------------------------------------
  context "with a Play Store URL containing only the id param" do
    let(:url) { "https://play.google.com/store/apps/details?id=com.example.app" }

    it "returns the play_store_id" do
      expect(result[:play_store_id]).to eq("com.example.app")
    end

    it "does not include an app_store_id key" do
      expect(result).not_to have_key(:app_store_id)
    end
  end

  # ---------------------------------------------------------------------------
  # Play Store — id with additional query params
  # ---------------------------------------------------------------------------
  context "with a Play Store URL containing extra query params" do
    let(:url) { "https://play.google.com/store/apps/details?id=com.example.app&hl=en" }

    it "returns the play_store_id ignoring extra params" do
      expect(result[:play_store_id]).to eq("com.example.app")
    end
  end

  # ---------------------------------------------------------------------------
  # Unrecognized / invalid URLs
  # ---------------------------------------------------------------------------
  context "with an unrecognized URL" do
    let(:url) { "https://www.example.com/some/random/page" }

    it "returns nil" do
      expect(result).to be_nil
    end
  end

  context "with an empty string" do
    let(:url) { "" }

    it "returns nil" do
      expect(result).to be_nil
    end
  end

  context "with nil" do
    let(:url) { nil }

    it "returns nil" do
      expect(result).to be_nil
    end
  end
end
