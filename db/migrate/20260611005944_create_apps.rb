# frozen_string_literal: true

class CreateApps < ActiveRecord::Migration[8.0]
  def change
    create_table :apps do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.string :app_store_id
      t.string :app_store_country, default: "us"
      t.string :play_store_id
      t.integer :created_by_user_id, null: false

      t.timestamps
    end

    add_foreign_key :apps, :users, column: :created_by_user_id
  end
end
