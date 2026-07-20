# frozen_string_literal: true

class AppsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_workspace

  def show
    @app = @workspace.apps.find(params[:id])
    authorize @app
    @latest_report = @app.reports.complete.order(created_at: :desc).first
    @active_report = @app.reports.where(status: [:pending, :fetching, :analyzing]).order(created_at: :desc).first
  end

  def new
    @app = @workspace.apps.build
    authorize @app
  end

  def create
    @app = @workspace.apps.build(app_params)
    @app.created_by_user_id = current_user.id
    authorize @app

    parse_store_urls

    if @app.errors.none? && @app.save
      redirect_to workspace_app_path(@workspace, @app)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @app = @workspace.apps.find(params[:id])
    authorize @app
    @app.app_store_url  = app_store_display_url(@app)
    @app.play_store_url = play_store_display_url(@app)
  end

  def update
    @app = @workspace.apps.find(params[:id])
    authorize @app

    @app.assign_attributes(app_params)
    update_store_urls

    if @app.errors.none? && @app.save
      redirect_to workspace_app_path(@workspace, @app)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @app = @workspace.apps.find(params[:id])
    authorize @app
    @app.destroy
    redirect_to workspace_path(@workspace), status: :see_other
  end

  private

  def set_workspace
    @workspace = Workspace.joins(:workspace_memberships)
                          .find_by!(id: params[:workspace_id],
                                    workspace_memberships: { user_id: current_user.id })
  end

  def app_params
    params.require(:app).permit(:name)
  end

  def parse_store_urls
    app_store_url  = params.dig(:app, :app_store_url).to_s.strip
    play_store_url = params.dig(:app, :play_store_url).to_s.strip

    if app_store_url.present?
      result = Apps::StoreUrlParser.call(app_store_url)
      if result && result[:app_store_id]
        @app.app_store_id      = result[:app_store_id]
        @app.app_store_country = result[:app_store_country]
      else
        @app.errors.add(:app_store_url, :invalid, message: "App Store URL format not recognized")
      end
    end

    if play_store_url.present?
      result = Apps::StoreUrlParser.call(play_store_url)
      if result && result[:play_store_id]
        @app.play_store_id = result[:play_store_id]
      else
        @app.errors.add(:play_store_url, :invalid, message: "Play Store URL format not recognized")
      end
    end
  end

  def update_store_urls
    app_store_url  = params.dig(:app, :app_store_url).to_s.strip
    play_store_url = params.dig(:app, :play_store_url).to_s.strip

    if app_store_url == app_store_display_url(@app)
      # unchanged from the pre-filled edit form value — keep the existing app_store_id/country
    elsif app_store_url.present?
      result = Apps::StoreUrlParser.call(app_store_url)
      if result && result[:app_store_id]
        @app.app_store_id      = result[:app_store_id]
        @app.app_store_country = result[:app_store_country]
      else
        @app.errors.add(:app_store_url, :invalid, message: "App Store URL format not recognized")
      end
    else
      @app.app_store_id      = nil
      @app.app_store_country = nil
    end

    if play_store_url == play_store_display_url(@app)
      # unchanged from the pre-filled edit form value — keep the existing play_store_id
    elsif play_store_url.present?
      result = Apps::StoreUrlParser.call(play_store_url)
      if result && result[:play_store_id]
        @app.play_store_id = result[:play_store_id]
      else
        @app.errors.add(:play_store_url, :invalid, message: "Play Store URL format not recognized")
      end
    else
      @app.play_store_id = nil
    end
  end

  def app_store_display_url(app)
    return nil if app.app_store_id.blank?

    "https://apps.apple.com/#{app.app_store_country}/app/id#{app.app_store_id}"
  end

  def play_store_display_url(app)
    return nil if app.play_store_id.blank?

    "https://play.google.com/store/apps/details?id=#{app.play_store_id}"
  end
end
