# frozen_string_literal: true

require "rails_helper"
require "nokogiri"

# BRA-44: Sign-in Google button uses button_to (POST form) instead of link_to (anchor)
RSpec.describe "GET /sign_in — Google OAuth button", type: :request do
  include Devise::Test::IntegrationHelpers

  before { get sign_in_path }

  let(:doc) { Nokogiri::HTML(response.body) }

  # AC: Sign-in button uses `button_to`, not `link_to`
  # button_to renders a <form> wrapping a <button>; link_to renders an <a> tag
  it "does not render an anchor tag linking to the OAuth path" do
    anchors = doc.css("a[href='#{user_google_oauth2_omniauth_authorize_path}']")
    expect(anchors).to be_empty
  end

  it "renders a form that posts to the Google OAuth path" do
    forms = doc.css("form[action='#{user_google_oauth2_omniauth_authorize_path}']")
    expect(forms).not_to be_empty
  end

  # AC: Request method is `POST`
  it "the OAuth form uses POST method" do
    form = doc.css("form[action='#{user_google_oauth2_omniauth_authorize_path}']").first
    # Rails button_to with method: :post emits method="post" on the form element
    expect(form["method"].downcase).to eq("post")
  end

  # AC: `data: { turbo: false }` is present on the button
  # Rails' button_to places data-turbo on the <button> element (not the <form>)
  it "sets data-turbo='false' on the submit button so Turbo does not intercept the OAuth redirect" do
    form = doc.css("form[action='#{user_google_oauth2_omniauth_authorize_path}']").first
    button = form.css("button[type='submit']").first
    expect(button["data-turbo"]).to eq("false")
  end

  # AC: Button renders the Google logo icon alongside the text
  it "renders an img tag inside the OAuth form (Google logo)" do
    form = doc.css("form[action='#{user_google_oauth2_omniauth_authorize_path}']").first
    img = form.css("img")
    expect(img).not_to be_empty
  end

  it "the Google logo img has alt text 'Google'" do
    form = doc.css("form[action='#{user_google_oauth2_omniauth_authorize_path}']").first
    img = form.css("img").first
    expect(img["alt"]).to eq("Google")
  end

  it "renders the 'Sign in with Google' button text" do
    form = doc.css("form[action='#{user_google_oauth2_omniauth_authorize_path}']").first
    expect(form.text).to include("Sign in with Google")
  end
end
