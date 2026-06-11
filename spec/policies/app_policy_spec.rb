# frozen_string_literal: true

require "rails_helper"

RSpec.describe AppPolicy, type: :policy do
  subject(:policy) { described_class.new(user, app) }

  let(:workspace) { create(:workspace) }
  let(:app)       { create(:app, workspace: workspace) }

  # ---------------------------------------------------------------------------
  # Helper — build a user with a specific membership role in the workspace
  # ---------------------------------------------------------------------------
  def user_with_role(role)
    u = create(:user)
    create(:workspace_membership, user: u, workspace: workspace, role: role)
    u
  end

  # ---------------------------------------------------------------------------
  # collaborator — can view, cannot create/edit/destroy
  # ---------------------------------------------------------------------------
  context "as collaborator" do
    let(:user) { user_with_role(:collaborator) }

    it "permits show?" do
      expect(policy.show?).to be true
    end

    it "denies create?" do
      expect(policy.create?).to be false
    end

    it "denies new?" do
      expect(policy.new?).to be false
    end

    it "denies update?" do
      expect(policy.update?).to be false
    end

    it "denies edit?" do
      expect(policy.edit?).to be false
    end

    it "denies destroy?" do
      expect(policy.destroy?).to be false
    end
  end

  # ---------------------------------------------------------------------------
  # admin — can do everything
  # ---------------------------------------------------------------------------
  context "as admin" do
    let(:user) { user_with_role(:admin) }

    it "permits show?" do
      expect(policy.show?).to be true
    end

    it "permits create?" do
      expect(policy.create?).to be true
    end

    it "permits new?" do
      expect(policy.new?).to be true
    end

    it "permits update?" do
      expect(policy.update?).to be true
    end

    it "permits edit?" do
      expect(policy.edit?).to be true
    end

    it "permits destroy?" do
      expect(policy.destroy?).to be true
    end
  end

  # ---------------------------------------------------------------------------
  # super_admin — can do everything
  # ---------------------------------------------------------------------------
  context "as super_admin" do
    let(:user) { user_with_role(:super_admin) }

    it "permits show?" do
      expect(policy.show?).to be true
    end

    it "permits create?" do
      expect(policy.create?).to be true
    end

    it "permits new?" do
      expect(policy.new?).to be true
    end

    it "permits update?" do
      expect(policy.update?).to be true
    end

    it "permits edit?" do
      expect(policy.edit?).to be true
    end

    it "permits destroy?" do
      expect(policy.destroy?).to be true
    end
  end

  # ---------------------------------------------------------------------------
  # non-member — no access to any action
  # ---------------------------------------------------------------------------
  context "as non-member" do
    let(:user) { create(:user) }

    it "denies show?" do
      expect(policy.show?).to be_falsey
    end

    it "denies create?" do
      expect(policy.create?).to be_falsey
    end

    it "denies new?" do
      expect(policy.new?).to be_falsey
    end

    it "denies update?" do
      expect(policy.update?).to be_falsey
    end

    it "denies edit?" do
      expect(policy.edit?).to be_falsey
    end

    it "denies destroy?" do
      expect(policy.destroy?).to be_falsey
    end
  end

  # ---------------------------------------------------------------------------
  # Scope
  # ---------------------------------------------------------------------------
  describe "Scope" do
    subject(:scope) { described_class::Scope.new(user, App).resolve }

    context "when the user is a member of the workspace" do
      let(:user) { user_with_role(:collaborator) }

      it "includes apps belonging to their workspace" do
        expect(scope).to include(app)
      end

      it "excludes apps from workspaces the user does not belong to" do
        other_workspace = create(:workspace)
        other_app = create(:app, workspace: other_workspace)
        expect(scope).not_to include(other_app)
      end
    end

    context "when the user has no workspace memberships" do
      let(:user) { create(:user) }

      it "returns an empty collection" do
        expect(scope).to be_empty
      end
    end
  end
end
