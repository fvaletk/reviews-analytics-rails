# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sessions", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user) }

  # AC: Signed-out user visiting `/` is redirected to `/sign_in`
  describe "GET /" do
    context "when not signed in" do
      it "redirects to sign_in path" do
        get root_path
        expect(response).to redirect_to(sign_in_path)
      end
    end

    context "when signed in" do
      before { sign_in user }

      it "returns 200 OK" do
        get root_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # AC: Sign-in page shows only a "Sign in with Google" button
  describe "GET /sign_in" do
    context "when not signed in" do
      it "returns 200 OK" do
        get sign_in_path
        expect(response).to have_http_status(:ok)
      end

      it "renders a link to the Google OAuth path" do
        get sign_in_path
        expect(response.body).to include(user_google_oauth2_omniauth_authorize_path)
      end

      it "includes the 'Sign in with Google' text" do
        get sign_in_path
        expect(response.body).to include("Sign in with Google")
      end
    end

    context "when already signed in" do
      before { sign_in user }

      it "redirects to root path" do
        get sign_in_path
        expect(response).to redirect_to(root_path)
      end
    end
  end

  # AC: "Sign out" link ends the session and redirects to sign-in page
  describe "DELETE /sign_out" do
    context "when signed in" do
      before { sign_in user }

      it "redirects to sign_in path" do
        delete sign_out_path
        expect(response).to redirect_to(sign_in_path)
      end

      it "ends the session so subsequent requests require sign-in again" do
        delete sign_out_path
        get root_path
        expect(response).to redirect_to(sign_in_path)
      end
    end
  end
end
