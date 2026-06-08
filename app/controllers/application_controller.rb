# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  after_action :verify_authorized, unless: :devise_controller?

  rescue_from Pundit::NotAuthorizedError do
    render file: Rails.root.join("public/404.html"), status: :not_found
  end

  private

  def authenticate_user!
    redirect_to sign_in_path unless user_signed_in?
  end

  def membership_in(workspace)
    current_user.workspace_memberships.find_by(workspace: workspace)
  end
end
