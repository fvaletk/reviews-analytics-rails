# frozen_string_literal: true

class CreateReviews < ActiveRecord::Migration[8.0]
  def change
    create_table :reviews do |t|
      t.references :app, null: false, foreign_key: true
      t.integer :store, null: false
      t.string :external_id, null: false
      t.string :author
      t.integer :rating
      t.string :title
      t.text :body
      t.datetime :reviewed_at
      t.datetime :fetched_at

      t.timestamps
    end

    add_index :reviews, [:app_id, :store, :external_id], unique: true
  end
end
