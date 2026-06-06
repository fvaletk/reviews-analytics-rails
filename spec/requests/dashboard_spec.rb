# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user) }

  # AC: After OAuth, user lands on dashboard showing their name and email
  describe "GET / (dashboard)" do
    context "when signed in" do
      before { sign_in user }

      it "returns 200 OK" do
        get root_path
        expect(response).to have_http_status(:ok)
      end

      it "displays the user's name" do
        get root_path
        expect(response.body).to include(user.name)
      end

      it "displays the user's email" do
        get root_path
        expect(response.body).to include(user.email)
      end

      it "includes a sign out link" do
        get root_path
        expect(response.body).to include("Sign out")
      end
    end

    context "when not signed in" do
      it "redirects to sign_in path" do
        get root_path
        expect(response).to redirect_to(sign_in_path)
      end
    end
  end
end
