# frozen_string_literal: true

class AddLlmUsageToReports < ActiveRecord::Migration[8.0]
  def change
    add_column :reports, :model,           :string
    add_column :reports, :input_tokens,    :integer
    add_column :reports, :output_tokens,   :integer
    add_column :reports, :thinking_tokens, :integer
    add_column :reports, :llm_duration_ms, :integer
    add_column :reports, :cost_usd,        :decimal, precision: 12, scale: 6
    add_column :reports, :usage_metadata,  :jsonb, default: {}, null: false

    add_index :reports, :model
  end
end
