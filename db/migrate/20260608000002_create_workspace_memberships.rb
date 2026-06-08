# frozen_string_literal: true

class CreateWorkspaceMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :workspace_memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :workspace, null: false, foreign_key: true
      t.integer :role, null: false
      t.integer :invited_by_user_id
      t.datetime :joined_at

      t.timestamps
    end

    add_index :workspace_memberships, %i[user_id workspace_id], unique: true
  end
end
