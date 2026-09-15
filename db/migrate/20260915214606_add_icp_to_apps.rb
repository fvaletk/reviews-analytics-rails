# frozen_string_literal: true

class AddIcpToApps < ActiveRecord::Migration[8.0]
  def change
    add_column :apps, :icp,                 :jsonb
    add_column :apps, :icp_declined_reason, :text
    add_column :apps, :icp_model,           :string
    add_column :apps, :icp_input_tokens,    :integer
    add_column :apps, :icp_output_tokens,   :integer
    add_column :apps, :icp_cost_usd,        :decimal, precision: 12, scale: 6
    add_column :apps, :icp_generated_at,    :datetime
    add_column :apps, :icp_usage_metadata,  :jsonb, default: {}, null: false

    add_index :apps, :icp_model
  end
end
