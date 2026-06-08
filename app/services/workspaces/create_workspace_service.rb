# frozen_string_literal: true

module Workspaces
  class CreateWorkspaceService
    Error = Class.new(StandardError)

    def self.call(name:, user:)
      new(name: name, user: user).call
    end

    def initialize(name:, user:)
      @name = name
      @user = user
    end

    def call
      workspace = nil

      ActiveRecord::Base.transaction do
        workspace = Workspace.new(name: @name)
        ensure_unique_slug(workspace)

        unless workspace.save
          raise Error, workspace.errors.full_messages.to_sentence
        end

        workspace.workspace_memberships.create!(
          user: @user,
          role: :super_admin,
          joined_at: Time.current
        )
      end

      workspace
    end

    private

    def ensure_unique_slug(workspace)
      # The model's before_validation sets the base slug from name.
      # Run validation to trigger the callback so we can inspect the slug.
      workspace.valid?
      base_slug = workspace.slug
      return if base_slug.blank?

      candidate = base_slug
      counter = 2

      while Workspace.exists?(slug: candidate)
        candidate = "#{base_slug}-#{counter}"
        counter += 1
      end

      workspace.slug = candidate
    end
  end
end
