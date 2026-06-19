# frozen_string_literal: true

class CreateReports < ActiveRecord::Migration[8.0]
  def change
    create_table :reports do |t|
      t.references :app, null: false, foreign_key: true
      t.references :generated_by_user, null: false, foreign_key: { to_table: :users }
      t.integer :status, null: false, default: 0
      t.text :failure_reason
      t.jsonb :structured_output
      t.integer :total_reviews_analyzed, default: 0, null: false
      t.datetime :reviews_fetched_at

      t.timestamps
    end
  end
end
