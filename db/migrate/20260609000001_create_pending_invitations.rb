# frozen_string_literal: true

class CreatePendingInvitations < ActiveRecord::Migration[8.0]
  def change
    create_table :pending_invitations do |t|
      t.string  :email,              null: false
      t.references :workspace,       null: false, foreign_key: true
      t.integer :role,               null: false
      t.integer :invited_by_user_id

      t.timestamps
    end

    add_index :pending_invitations, %i[email workspace_id], unique: true
  end
end
