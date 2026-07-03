# frozen_string_literal: true

class ReportChannel < ApplicationCable::Channel
  def subscribed
    stream_from "report_#{params[:report_id]}"
  end

  def unsubscribed
    stop_all_streams
  end
end
