# frozen_string_literal: true

class AddReportTypeToReports < ActiveRecord::Migration[8.0]
  def change
    add_column :reports, :report_type, :integer, default: 0, null: false
  end
end
