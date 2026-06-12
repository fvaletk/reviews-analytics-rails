# frozen_string_literal: true

require "rails_helper"
require "cgi"

# BRA-47: Replace "Welcome back" banner with user avatar dropdown in navbar
RSpec.describe "Navbar", type: :request do
  include Devise::Test::IntegrationHelpers

  describe "avatar dropdown rendered on authenticated pages" do
    context "when signed in with a user who has an avatar_url" do
      let(:user) { create(:user, avatar_url: "https://example.com/photo.jpg") }

      before { sign_in user }

      # AC: "Welcome back" banner and plain name/email text are removed
      it "does not render a 'Welcome back' banner" do
        get root_path
        expect(response.body).not_to include("Welcome back")
      end

      # AC: Circular avatar renders with Google photo
      it "renders an img tag pointing to the user's avatar_url" do
        get root_path
        expect(response.body).to include(%(<img src="#{user.avatar_url}"))
      end

      it "sets the img alt attribute to the user's name" do
        get root_path
        expect(response.body).to include(%(alt="#{CGI.escapeHTML(user.name)}"))
      end

      it "does not render the initials fallback span" do
        get root_path
        expect(response.body).not_to include('class="avatar-initials"')
      end

      # AC: Clicking avatar opens dropdown with name, email, and sign out
      it "renders the user's name inside the dropdown" do
        get root_path
        expect(response.body).to include(%(class="avatar-menu-name"))
        expect(response.body).to include(CGI.escapeHTML(user.name))
      end

      it "renders the user's email inside the dropdown" do
        get root_path
        expect(response.body).to include(%(class="avatar-menu-email"))
        expect(response.body).to include(user.email)
      end

      # AC: Sign out works correctly from the dropdown
      it "renders a Sign out link" do
        get root_path
        expect(response.body).to include("Sign out")
      end

      it "sets data-turbo-method='delete' on the sign out link" do
        get root_path
        expect(response.body).to include("data-turbo-method")
        expect(response.body).to match(/data-turbo-method="delete"/i)
          .or match(/data-turbo-method=\\"delete\\"/)
      end

      it "points the sign out link to sign_out_path" do
        get root_path
        expect(response.body).to include(sign_out_path)
      end

      # AC: dropdown uses Stimulus controller for open/close
      it "renders the avatar-dropdown Stimulus controller attribute" do
        get root_path
        expect(response.body).to include('data-controller="avatar-dropdown"')
      end

      it "renders the toggle action on the avatar button" do
        get root_path
        expect(response.body).to include("avatar-dropdown#toggle")
      end
    end

    context "when signed in with a user who has no avatar_url" do
      let(:user) { create(:user, avatar_url: nil) }

      before { sign_in user }

      # AC: Circular avatar renders with initials fallback
      it "does not render an img tag for the avatar" do
        get root_path
        expect(response.body).not_to include('class="avatar-photo"')
      end

      it "renders the initials fallback span" do
        get root_path
        expect(response.body).to include('class="avatar-initials"')
      end

      it "renders the first character of the user's name as the initial" do
        get root_path
        expect(response.body).to include(user.name.first)
      end
    end

    context "when signed in with a user whose name is nil" do
      let(:user) { create(:user, name: nil, avatar_url: nil) }

      before { sign_in user }

      it "falls back to the first character of the email for initials" do
        get root_path
        expect(response.body).to include('class="avatar-initials"')
        expect(response.body).to include(user.email.first)
      end
    end

    context "when not signed in" do
      it "does not render the navbar" do
        get sign_in_path
        expect(response.body).not_to include('data-controller="avatar-dropdown"')
      end
    end
  end

  # BRA-48: navbar logo links to root_path on all authenticated pages
  describe "navbar logo href" do
    let(:user) { create(:user) }

    before { sign_in user }

    it "links the navbar logo to root_path on the dashboard" do
      get root_path
      expect(response.body).to include(%(<a class="navbar-logo" href="#{root_path}"))
    end

    context "on the workspace show page" do
      let(:workspace) { create(:workspace) }

      before do
        create(:workspace_membership, user: user, workspace: workspace, role: :collaborator)
      end

      it "links the navbar logo to root_path" do
        get workspace_path(workspace)
        expect(response.body).to include(%(<a class="navbar-logo" href="#{root_path}"))
      end
    end
  end

  # AC: navbar is also present on workspace show page
  describe "navbar on workspace show page" do
    let(:user) { create(:user, avatar_url: "https://example.com/photo.jpg") }
    let(:workspace) { create(:workspace) }

    before do
      create(:workspace_membership, user: user, workspace: workspace, role: :admin)
      sign_in user
    end

    it "renders the avatar dropdown on the workspace show page" do
      get workspace_path(workspace)
      expect(response.body).to include('data-controller="avatar-dropdown"')
    end

    it "does not render 'Welcome back' on the workspace show page" do
      get workspace_path(workspace)
      expect(response.body).not_to include("Welcome back")
    end
  end
end
