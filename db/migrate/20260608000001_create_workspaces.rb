# frozen_string_literal: true

class CreateWorkspaces < ActiveRecord::Migration[8.0]
  def change
    create_table :workspaces do |t|
      t.string :name, null: false
      t.string :slug, null: false

      t.timestamps
    end

    add_index :workspaces, :slug, unique: true
  end
end
