# frozen_string_literal: true

module Workspaces
  class InviteMemberService
    Error = Class.new(StandardError)

    INVITABLE_ROLES = %w[collaborator admin].freeze

    def self.call(workspace:, email:, role:, invited_by:)
      new(workspace: workspace, email: email, role: role, invited_by: invited_by).call
    end

    def initialize(workspace:, email:, role:, invited_by:)
      @workspace  = workspace
      @email      = email.to_s.strip.downcase
      @role       = role.to_s
      @invited_by = invited_by
    end

    def call
      validate_role!

      user = User.find_by(email: @email)

      if user
        create_membership_for_existing_user(user)
      else
        create_pending_invitation
      end
    end

    private

    def validate_role!
      raise Error, "Role must be collaborator or admin" unless INVITABLE_ROLES.include?(@role)
    end

    def create_membership_for_existing_user(user)
      if @workspace.workspace_memberships.exists?(user: user)
        raise Error, "#{@email} is already a member of this workspace"
      end

      @workspace.workspace_memberships.create!(
        user:                 user,
        role:                 @role,
        joined_at:            Time.current,
        invited_by_user_id:   @invited_by.id
      )
    end

    def create_pending_invitation
      invitation = @workspace.pending_invitations.find_or_initialize_by(email: @email)

      if invitation.persisted?
        raise Error, "#{@email} has already been invited to this workspace"
      end

      invitation.role              = @role
      invitation.invited_by_user_id = @invited_by.id
      invitation.save!
      invitation
    end
  end
end
