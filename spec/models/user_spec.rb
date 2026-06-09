# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  describe "Devise modules" do
    it "includes omniauthable" do
      expect(described_class.devise_modules).to include(:omniauthable)
    end

    it "includes rememberable" do
      expect(described_class.devise_modules).to include(:rememberable)
    end

    it "includes trackable" do
      expect(described_class.devise_modules).to include(:trackable)
    end

    it "does not include database_authenticatable" do
      expect(described_class.devise_modules).not_to include(:database_authenticatable)
    end
  end

  describe "schema" do
    subject(:columns) { described_class.column_names }

    it "has an email column" do
      expect(columns).to include("email")
    end

    it "has a name column" do
      expect(columns).to include("name")
    end

    it "has an avatar_url column" do
      expect(columns).to include("avatar_url")
    end

    it "has a provider column" do
      expect(columns).to include("provider")
    end

    it "has a uid column" do
      expect(columns).to include("uid")
    end

    it "has a remember_created_at column" do
      expect(columns).to include("remember_created_at")
    end

    it "has a sign_in_count column" do
      expect(columns).to include("sign_in_count")
    end

    it "has a current_sign_in_at column" do
      expect(columns).to include("current_sign_in_at")
    end

    it "has a last_sign_in_at column" do
      expect(columns).to include("last_sign_in_at")
    end

    it "has a current_sign_in_ip column" do
      expect(columns).to include("current_sign_in_ip")
    end

    it "has a last_sign_in_ip column" do
      expect(columns).to include("last_sign_in_ip")
    end

    it "does not have an encrypted_password column" do
      expect(columns).not_to include("encrypted_password")
    end
  end

  describe "unique index on (provider, uid)" do
    it "exists on the users table" do
      indexes = ActiveRecord::Base.connection.indexes(:users)
      provider_uid_index = indexes.find do |idx|
        idx.columns == %w[provider uid]
      end

      expect(provider_uid_index).not_to be_nil
      expect(provider_uid_index.unique).to be true
    end
  end

  describe "validations" do
    it "is valid with valid attributes" do
      user = build(:user)
      expect(user).to be_valid
    end

    it "is invalid without an email" do
      user = build(:user, email: nil)
      expect(user).not_to be_valid
    end

    it "is invalid with a duplicate email" do
      create(:user, email: "taken@example.com")
      user = build(:user, email: "taken@example.com")
      expect(user).not_to be_valid
    end

    it "is invalid without a provider" do
      user = build(:user, provider: nil)
      expect(user).not_to be_valid
    end

    it "is invalid without a uid" do
      user = build(:user, uid: nil)
      expect(user).not_to be_valid
    end
  end

  describe "associations" do
    it "has many workspace_memberships" do
      association = described_class.reflect_on_association(:workspace_memberships)
      expect(association.macro).to eq(:has_many)
    end

    it "destroys workspace_memberships when user is destroyed" do
      association = described_class.reflect_on_association(:workspace_memberships)
      expect(association.options[:dependent]).to eq(:destroy)
    end

    it "has many workspaces through workspace_memberships" do
      association = described_class.reflect_on_association(:workspaces)
      expect(association.macro).to eq(:has_many)
      expect(association.options[:through]).to eq(:workspace_memberships)
    end

    it "returns workspaces through memberships" do
      user = create(:user)
      workspace = create(:workspace)
      create(:workspace_membership, user: user, workspace: workspace)
      expect(user.workspaces).to include(workspace)
    end

    it "cleans up memberships when user is destroyed" do
      user = create(:user)
      workspace = create(:workspace)
      create(:workspace_membership, user: user, workspace: workspace)
      expect { user.destroy }.to change(WorkspaceMembership, :count).by(-1)
    end
  end

  describe "database constraints" do
    it "enforces uniqueness of (provider, uid) at the database level" do
      existing = create(:user, provider: "google_oauth2", uid: "abc123")
      duplicate = build(:user, provider: existing.provider, uid: existing.uid)

      expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe ".from_omniauth" do
    let(:auth) do
      OmniAuth::AuthHash.new(
        provider: "google_oauth2",
        uid: "123456789",
        info: {
          email: "test@example.com",
          name: "Test User",
          image: "https://example.com/avatar.jpg"
        }
      )
    end

    context "when no user exists with the given provider and uid" do
      it "creates a new user" do
        expect { described_class.from_omniauth(auth) }.to change(User, :count).by(1)
      end

      it "sets email from auth hash" do
        user = described_class.from_omniauth(auth)
        expect(user.email).to eq("test@example.com")
      end

      it "sets name from auth hash" do
        user = described_class.from_omniauth(auth)
        expect(user.name).to eq("Test User")
      end

      it "sets avatar_url from auth hash info.image" do
        user = described_class.from_omniauth(auth)
        expect(user.avatar_url).to eq("https://example.com/avatar.jpg")
      end

      it "persists the user" do
        user = described_class.from_omniauth(auth)
        expect(user).to be_persisted
      end
    end

    context "when a user already exists with the given provider and uid" do
      let!(:existing_user) do
        create(:user, provider: "google_oauth2", uid: "123456789",
               email: "old@example.com", name: "Old Name", avatar_url: "https://example.com/old.jpg")
      end

      it "does not create a new user" do
        expect { described_class.from_omniauth(auth) }.not_to change(User, :count)
      end

      it "returns the existing user" do
        user = described_class.from_omniauth(auth)
        expect(user.id).to eq(existing_user.id)
      end

      it "updates the email" do
        user = described_class.from_omniauth(auth)
        expect(user.email).to eq("test@example.com")
      end

      it "updates the name" do
        user = described_class.from_omniauth(auth)
        expect(user.name).to eq("Test User")
      end

      it "updates the avatar_url" do
        user = described_class.from_omniauth(auth)
        expect(user.avatar_url).to eq("https://example.com/avatar.jpg")
      end
    end
  end

  describe "#activate_pending_invitations!" do
    let(:user)      { create(:user, email: "pending@example.com") }
    let(:workspace) { create(:workspace) }

    context "when there are pending invitations matching the user's email" do
      let!(:invitation) do
        create(:pending_invitation, workspace: workspace, email: "pending@example.com", role: :admin)
      end

      it "creates a WorkspaceMembership for the user" do
        expect { user.activate_pending_invitations! }.to change(WorkspaceMembership, :count).by(1)
      end

      it "sets joined_at on the new membership" do
        user.activate_pending_invitations!
        membership = WorkspaceMembership.find_by(user: user, workspace: workspace)
        expect(membership.joined_at).not_to be_nil
      end

      it "assigns the role from the invitation" do
        user.activate_pending_invitations!
        membership = WorkspaceMembership.find_by(user: user, workspace: workspace)
        expect(membership.role).to eq("admin")
      end

      it "destroys the PendingInvitation after activation" do
        expect { user.activate_pending_invitations! }.to change(PendingInvitation, :count).by(-1)
      end

      it "activates multiple pending invitations across different workspaces" do
        other_workspace = create(:workspace)
        create(:pending_invitation, workspace: other_workspace, email: "pending@example.com", role: :collaborator)

        expect { user.activate_pending_invitations! }.to change(WorkspaceMembership, :count).by(2)
      end
    end

    context "when the user is already a member of the invited workspace" do
      let!(:invitation) do
        create(:pending_invitation, workspace: workspace, email: "pending@example.com", role: :admin)
      end

      before { create(:workspace_membership, user: user, workspace: workspace, role: :collaborator) }

      it "does not create a duplicate WorkspaceMembership" do
        expect { user.activate_pending_invitations! }.not_to change(WorkspaceMembership, :count)
      end
    end

    context "when there are no pending invitations for the user" do
      it "does not create any WorkspaceMembership" do
        expect { user.activate_pending_invitations! }.not_to change(WorkspaceMembership, :count)
      end
    end

    context "called via User.from_omniauth for a new sign-in" do
      let!(:invitation) do
        create(:pending_invitation, workspace: workspace, email: "oauth-pending@example.com", role: :collaborator)
      end

      let(:auth) do
        OmniAuth::AuthHash.new(
          provider: "google_oauth2",
          uid:      SecureRandom.hex,
          info: {
            email: "oauth-pending@example.com",
            name:  "OAuth User",
            image: nil
          }
        )
      end

      it "activates the pending invitation during OAuth sign-in" do
        expect { described_class.from_omniauth(auth) }.to change(WorkspaceMembership, :count).by(1)
      end

      it "destroys the PendingInvitation during OAuth sign-in" do
        expect { described_class.from_omniauth(auth) }.to change(PendingInvitation, :count).by(-1)
      end
    end
  end
end
