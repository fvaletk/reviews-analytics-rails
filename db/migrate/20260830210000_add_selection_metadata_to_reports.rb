# frozen_string_literal: true

class AddSelectionMetadataToReports < ActiveRecord::Migration[8.0]
  def change
    add_column :reports, :selection_metadata, :jsonb, default: {}, null: false
  end
end
