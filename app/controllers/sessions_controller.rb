# frozen_string_literal: true

class SessionsController < ApplicationController
  skip_after_action :verify_authorized

  def new
    redirect_to root_path if user_signed_in?
  end

  def destroy
    sign_out(:user)
    redirect_to sign_in_path
  end
end
