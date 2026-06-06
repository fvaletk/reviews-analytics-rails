# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Users::OmniauthCallbacksController", type: :request do
  include Rails.application.routes.url_helpers

  let(:auth_hash) do
    OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "987654321",
      info: {
        email: "oauth@example.com",
        name: "OAuth User",
        image: "https://example.com/photo.jpg"
      }
    )
  end

  before do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = auth_hash
    Rails.application.env_config["omniauth.auth"] = auth_hash
  end

  after do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end

  describe "GET /users/auth/google_oauth2/callback" do
    context "when User.from_omniauth succeeds" do
      it "returns a redirect response" do
        get "/users/auth/google_oauth2/callback"
        expect(response).to be_redirect
      end

      it "redirects to root path ('/') after sign-in" do
        get "/users/auth/google_oauth2/callback"
        expect(response.location).to end_with("/")
      end

      it "creates the user when none exists" do
        expect { get "/users/auth/google_oauth2/callback" }.to change(User, :count).by(1)
      end

      it "finds an existing user rather than creating a duplicate" do
        create(:user, provider: "google_oauth2", uid: "987654321", email: "oauth@example.com")
        expect { get "/users/auth/google_oauth2/callback" }.not_to change(User, :count)
      end

      it "sets the user session cookie (warden key present)" do
        get "/users/auth/google_oauth2/callback"
        expect(response.headers["Set-Cookie"]).to include("_session")
      end
    end
  end
end
